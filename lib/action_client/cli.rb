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

  class BaseError < StandardError; end
  class InvalidInput < BaseError; end
  class UnexpectedError < BaseError
    MSG = 'An unexpected error has occurred!'

    def initialize(msg = MSG)
      super
    end
  end
  class ClientError < BaseError; end
  class InternalServerError < BaseError; end

  class CLI
    extend Commander::Delegates

    program :name, 'flight-action'
    program :version, ActionClient::VERSION
    program :description, 'Run a command on a node or over a group'
    program :help_paging, false

    silent_trace!

    def self.run!
      ARGV.push '--help' if ARGV.empty?
      super
    end

    def self.with_error_handling
      yield if block_given?
    rescue Interrupt
      raise RuntimeError, 'Received Interrupt!'
    rescue StandardError => e
      new_error_class = case e
                        when JsonApiClient::Errors::ConnectionError
                          nil
                        when JsonApiClient::Errors::NotFound
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

    def self.cli_syntax(command, args_str = '')
      command.hidden = true if command.name.split.length > 1
      command.syntax = <<~SYNTAX.chomp
        #{program(:name)} #{command.name} #{args_str}
      SYNTAX
    end

    def self.run_remote_action(cmd_id, context_id, group: false, output: nil, stdout: nil, status: nil, stderr: nil, verbose: nil)
      modes = { status: status, stdout: stdout, stderr: stderr, verbose: verbose }.select { |_, v| v }.keys
      mode = if modes.length > 1
               raise "The following flags can not be used together: #{modes.map { |v| "--#{v}" }.join(' ')}"
             elsif modes.length == 1
               modes.first
             elsif output
               Config::Cache.output_printing_mode
             else
               Config::Cache.printing_mode
             end

      # Build the associated objects for the request
      command = CommandRecord.new(id: cmd_id)
      context = (group ? GroupRecord : NodeRecord).new(id: context_id)

      # Create the ticket (and run the jobs)
      ticket = TicketRecord.create(relationships: { command: command, context: context })

      ticket.jobs.each do |job|
        if output
          FileUtils.mkdir_p(output)

          # Save Status
          path = File.expand_path("#{job.node.id}.status", output)
          File.write(path, job.status)

          # Save Stdout
          path = File.expand_path("#{job.node.id}.stdout", output)
          File.write(path, job.stdout)

          # Save Stderr
          path = File.expand_path("#{job.node.id}.stderr", output)
          File.write(path, job.stderr)
        end

        case mode
        when :status
          puts "#{job.node.id}: #{job.status}"
        when :stdout
          puts "#{job.node.id}: #{job.stdout}"
        when :stderr
          puts "#{job.node.id}: #{job.stderr}"
        when :verbose
          puts <<~JOB

            NODE: #{job.node.name}
            STATUS: #{job.status}
            STDOUT:
            #{job.stdout}

            STDERR:
            #{job.stderr}
          JOB
        else
          raise UnexpectedError
        end
      end

      # Assume missing jobs is because the context is missing
      # Technically the ticket was created successfully regardless and therefore the API didn't error
      # It is possible the command is missing, but this would require the CLI to be stale
      if ticket.jobs.empty?
        raise ClientError, "Could not find '#{context_id}'"
      end
    end

    begin
      with_error_handling do
        CommandRecord.all.each do |cmd|
          command cmd.name do |c|
            cli_syntax(c, 'NAME')
            c.summary = cmd.summary
            c.description = cmd.description
            c.option '-g', '--group', 'Run over the group of nodes given by NAME'
            c.option '-o', '--output DIRECTORY',
              'Save the results within the given directory'
            c.option '--status', 'Display the status only'
            c.option '--stdout', 'Display stdout only'
            c.option '--stderr', 'Display stderr only'
            c.option '--verbose', 'Display the status, stdout, and stderr'
            c.action do |args, opts|
              with_error_handling do
                hash_opts = opts.__hash__.tap { |h| h.delete(:trace) }
                run_remote_action(cmd.name, args.first, **hash_opts)
              end
            end
          end
        end
      end
    rescue StandardError => e
      runner = ::Commander::Runner.instance
      handler = runner.error_handler # NOTE: DO NOT give this method a block! It will set the handler!
      handler.call(runner, e)
    end
  end
end

