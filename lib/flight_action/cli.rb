# frozen_string_literal: true

#==============================================================================
# Copyright (C) 2020-present Alces Flight Ltd.
#
# This file is part of Flight Action.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# Flight Action is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with Flight Action. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on Flight Action, please visit:
# https://github.com/openflighthpc/flight-action
#===============================================================================

require 'commander'
require 'whirly'

module FlightAction
  VERSION = '1.0.1'

  class CLI
    include Commander::Methods

    def run
      namespace = ENV['FLIGHT_ACTION_NAMESPACE']

      program :name, program_name(namespace)
      program :version, FlightAction::VERSION
      program :description, program_description
      program :help_paging, false
      default_command :help
      silent_trace!

      begin
        with_error_handling do
          define_commands(namespace)
        end
      rescue StandardError => e
        runner = ::Commander::Runner.instance
        # NOTE: DO NOT give this method a block! It will set the handler!
        handler = runner.error_handler
        handler.call(runner, e)
      end

      run!
    end

    private

    def program_name(namespace)
      ENV.fetch('FLIGHT_PROGRAM_NAME') do
        namespace ? "flight-#{namespace}" : 'flight-action'
      end
    end

    def program_description
      ENV.fetch(
        'FLIGHT_ACTION_DESCRIPTION',
        'Run a pre-defined command on a node or over a group.'
      )
    end

    def with_error_handling
      yield if block_given?
    rescue Interrupt
      raise RuntimeError, 'Received Interrupt!'
    rescue StandardError => e
      raise_new = lambda do |new_error_class, ex|
        is_json_api_response =
          begin
            ex.env.response_headers['content-type'] == 'application/vnd.api+json'
          rescue
            false
          end
        if is_json_api_response
          raise new_error_class, <<~MESSAGE.chomp
          #{ex.env.body['errors'].map do |error| error['detail'] end.join("\n\n")}
          MESSAGE
        else
          raise new_error_class
        end
      end

      case e
      when JsonApiClient::Errors::ClientError
        raise_new.call(ClientError, e)
      when JsonApiClient::Errors::ServerError
        raise_new.call(InternalServerError, e)
      when JsonApiClient::Errors::ConnectionError
        raise_new.call(ConnectionError, e)
      else
        raise
      end
    end

    def run_remote_action(
      cmd_id,
      context_id,
      *args,
      exit_max_status: nil,
      group: nil,
      output: nil,
      prefix: nil,
      stderr: nil,
      stdout: nil
    )
      ticket = whirly do
        create_ticket(cmd_id, context_id, *args, group: group)
      end
      display_output(ticket, stdout: stdout, stderr: stderr, output: output, prefix: prefix)
      if exit_max_status
        exit ticket.jobs.map(&:status).max
      end
    end

    def create_ticket(
      cmd_id,
      context_id,
      *args,
      group: nil
    )
      # Build the associated objects for the request
      command = CommandRecord.new(id: cmd_id)
      context = (group ? GroupRecord : NodeRecord).new(id: context_id)
      # Create the ticket (and run the jobs)
      ticket = TicketRecord.create(
        attributes: { arguments: args },
        relationships: { command: command, context: context }
      )
      unless ticket.errors.empty?
        raise UnexpectedError, ticket.errors.full_messages
      end
      ticket
    end

    def display_output(ticket, stdout: nil, stderr: nil, output: nil, prefix: nil)
      streams = { stdout: stdout, stderr: stderr }.select { |_, v| v }.keys
      Formatter
        .new(jobs: ticket.jobs, streams: streams, output_dir: output, prefix: prefix)
        .run
    end

    def define_commands(namespace)
      CommandRecord.all.each do |cmd|
        if namespace && !cmd.name.start_with?("#{namespace}-")
          next
        end

        cmd_name = namespace ? cmd.name.sub("#{namespace}-", '') : cmd.name
        command cmd_name do |c|
          c.syntax = <<~SYNTAX.chomp
            #{program(:name)} #{cmd_name} #{cmd.syntax ? cmd.syntax : 'NAME'}
          SYNTAX
          c.summary = cmd.summary
          c.description = cmd.description.chomp
          c.option '-g', '--group', 'Run over the group of nodes given by NAME'
          if namespace.nil?
            c.option '-o', '--output DIRECTORY',
              'Save the results within the given directory'
            c.option '--[no-]prefix', 'Disable hostname: prefix on lines of output.'
            c.option '-S', 'Return the largest of the command return values.'
            c.option '--[no-]stdout', 'Display stdout'
            c.option '--[no-]stderr', 'Display stderr'
          end
          if cmd.confirmation
            c.option '--confirm', 'Answer yes to all questions'
          end
          c.action do |args, opts|
            with_error_handling do
              opts.default(
                group: false,
                S: false,
                stdout: Config::Cache.print_stdout?,
                stderr: Config::Cache.print_stderr?,
              )
              opts.default(prefix: opts.group)
              hash_opts = opts.__hash__.tap { |h| h.delete(:trace) }
              hash_opts[:exit_max_status] = hash_opts.delete(:S)

              with_confirmation(cmd, args, hash_opts) do
                run_remote_action(cmd.name, *args, **hash_opts)
              end
            end
          end
        end
      end
    end

    def with_confirmation(cmd, args, hash_opts, &block)
      if cmd.confirmation && !hash_opts.delete(:confirm)
        context_id = args.first
        format_options = {}.tap do |h|
          if hash_opts[:group]
            h[:nodes] = "group #{context_id}"
          else
            h[:nodes] = "#{context_id}"
          end
        end
        if highline.agree($terminal.color(cmd.confirmation % format_options, :yellow))
          block.call
        else
          say_warning("Cancelled request.")
        end
      else
        block.call
      end
    end

    delegate :say, to: :highline

    def highline
      @highline ||= HighLine.new
    end

    def whirly(&block)
      if $stdout.tty?
        r = nil
        Whirly.start(
          spinner: 'star',
          remove_after_stop: true,
          append_newline: false,
          status: "Proceeding with request...",
        ) do
          r = block.call
        end
        r
      else
        block.call
      end
    end
  end
end