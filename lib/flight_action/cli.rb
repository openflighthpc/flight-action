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

require_relative 'version'

module FlightAction
  class CLI
    include Commander::Methods

    def run
      namespace = ENV['FLIGHT_ACTION_NAMESPACE']

      program :application, program_name(namespace)
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
      group: nil
    )
      whirly_start
      ticket = create_ticket(cmd_id, context_id, *args, group: group)

      uri = URI("#{ticket.class.site}#{ticket.links.output_stream}")
      request = Net::HTTP::Get.new uri
      request['authorization'] = "Bearer #{Config::Cache.jwt_token}"
      use_ssl = uri.scheme == 'https'
      verify_mode = Config::Cache.verify_ssl? ?
        OpenSSL::SSL::VERIFY_PEER :
        OpenSSL::SSL::VERIFY_NONE

      Net::HTTP.start(uri.host, uri.port, use_ssl: use_ssl, verify_mode: verify_mode) do |http|
        http.request request do |response|
          response.read_body do |chunk|
            # We've got our first bit of streaming data back.  We can stop the
            # whirly.
            whirly_stop
            print chunk
          end
        end
      end
    ensure
      whirly_stop
    end

    def create_ticket(
      cmd_id,
      context_id,
      *args,
      group: nil
    )
      # Build the associated objects for the request
      # NOTE: Not all commands will have a context, however this has been added retrospectively
      command = CommandRecord.new(id: cmd_id)
      context = if context_id
        (group ? GroupRecord : NodeRecord).new(id: context_id)
      else
        nil
      end

      # Create the ticket (and run the jobs)
      ticket = TicketRecord.create(
        attributes: { arguments: args },
        relationships: { command: command }.tap { |r| r[:context] = context if context }
      )
      unless ticket.errors.empty?
        raise UnexpectedError, ticket.errors.full_messages
      end
      ticket
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
          if cmd['has-context']
            c.option '-g', '--group', 'Run over the group of nodes given by NAME'
          end
          if cmd.confirmation
            c.option '--confirm', 'Answer yes to all questions'
          end
          c.action do |args, opts|
            with_error_handling do
              opts.default(group: false)
              hash_opts = opts.__hash__.tap { |h| h.delete(:trace) }

              with_confirmation(cmd, args, hash_opts) do
                if cmd.has_context
                  run_remote_action(cmd.name, *args, **hash_opts)
                else
                  run_remote_action(cmd.name, nil, *args, **hash_opts)
                end
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

    def whirly_start
      return unless $stdout.tty?
      Whirly.start(
        spinner: 'star',
        remove_after_stop: true,
        append_newline: false,
        status: "Proceeding with request...",
      )
    end

    def whirly_stop
      return unless $stdout.tty?
      Whirly.stop
    end
  end
end
