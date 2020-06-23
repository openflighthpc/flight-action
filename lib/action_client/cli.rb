# frozen_string_literal: true

#==============================================================================
# Copyright (C) 2020-present Alces Flight Ltd.
#
# This file is part of Action Client.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# Action Client is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with Action Client. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on Action Client, please visit:
# https://github.com/openflighthpc/action-client-ruby
#===============================================================================

require 'commander'

module ActionClient
  VERSION = '0.1.1'

  class CLI
    include Commander::Methods

    def run
      namespace = ENV['FLIGHT_ACTION_NAMESPACE']

      program :name, namespace ? "flight-#{namespace}" : 'flight-action'
      program :version, ActionClient::VERSION
      program :description, program_description
      program :help_paging, false

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
      new_error_class = case e
                        when JsonApiClient::Errors::ConnectionError
                          nil
                        when JsonApiClient::Errors::NotFound, ActionClient::NotFound
                          nil
                        when JsonApiClient::Errors::ClientError
                          ClientError
                        when JsonApiClient::Errors::ServerError
                          InternalServerError
                        else
                          nil
                        end
      if new_error_class && e.env.response_headers['content-type'] == 'application/vnd.api+json'
        raise new_error_class, <<~MESSAGE.chomp
          #{e.env.body['errors'].map do |e| e['detail'] end.join("\n\n")}
        MESSAGE
      elsif e.is_a? JsonApiClient::Errors::NotFound
        raise ClientError, 'Resource Not Found'
      else
        raise e
      end
    end

    def run_remote_action(
      cmd_id,
      context_id,
      exit_max_status: nil,
      group: nil,
      output: nil,
      prefix: nil,
      stderr: nil,
      stdout: nil
    )
      streams = { stdout: stdout, stderr: stderr }.select { |_, v| v }.keys

      # Build the associated objects for the request
      command = CommandRecord.new(id: cmd_id)
      context = (group ? GroupRecord : NodeRecord).new(id: context_id)

      # Create the ticket (and run the jobs)
      ticket = TicketRecord.create(relationships: { command: command, context: context })

      unless ticket.errors.empty?
        raise UnexpectedError, ticket.errors.full_messages
      end

      Formatter
        .new(jobs: ticket.jobs, streams: streams, output_dir: output, prefix: prefix)
        .run

      if exit_max_status
        exit ticket.jobs.map(&:status).max
      end
    end

    def define_commands(namespace)
      CommandRecord.all.each do |cmd|
        if namespace && !cmd.name.start_with?("#{namespace}-")
          next
        end

        cmd_name = namespace ? cmd.name.sub("#{namespace}-", '') : cmd.name
        command cmd_name do |c|
          c.syntax = <<~SYNTAX.chomp
          #{program(:name)} #{cmd_name} NAME
          SYNTAX
          c.summary = cmd.summary
          c.description = cmd.description
          c.option '-g', '--group', 'Run over the group of nodes given by NAME'
          c.option '-o', '--output DIRECTORY',
            'Save the results within the given directory'
          c.option '--[no-]prefix', 'Disable hostname: prefix on lines of output.'
          c.option '-S', 'Return the largest of the command return values.'
          unless Config::Cache.hide_print_flags?
            c.option '--[no-]stdout', 'Display stdout'
            c.option '--[no-]stderr', 'Display stderr'
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
              run_remote_action(cmd.name, args.first, **hash_opts)
            end
          end
        end
      end
    end
  end
end
