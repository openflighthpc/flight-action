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
  VERSION = '0.1.0'

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

    def self.action(command, klass, method: :run!)
      command.action do |args, options|
        hash = options.__hash__
        hash.delete(:trace)
        begin
          begin
            if hash.empty?
              klass.public_send(method, *args)
            else
              klass.public_send(method, *args, **hash)
            end
          rescue Interrupt
            raise RuntimeError, 'Received Interrupt!'
          end
        rescue StandardError => e
          new_error_class = case e
                            when JsonApiClient::Errors::NotFound
                              nil
                            when JsonApiClient::Errors::ClientError
                              ClientError
                            when JsonApiClient::Errors::ServerError
                              InternalServerError
                            else
                              nil
                            end
          if new_error_class &&  e.env.response_headers['content-type'] == 'application/vnd.api+json'
            raise new_error_class, <<~MESSAGE.chomp
              #{e.message}
              #{e.env.body['errors'].map do |e| e['detail'] end.join("\n\n")}
            MESSAGE
          elsif e.is_a? JsonApiClient::Errors::NotFound
            raise ClientError, 'Resource Not Found'
          else
            raise e
          end
        end
      end
    end

    def self.cli_syntax(command, args_str = '')
      command.hidden = true if command.name.split.length > 1
      command.syntax = <<~SYNTAX.chomp
        #{program(:name)} #{command.name} #{args_str}
      SYNTAX
    end

    # command 'list-templates' do |c|
    #   cli_syntax(c)
    #   c.summary = 'Return all the available templates'
    #   action(c, Commands::List, method: :templates)
    # end

    # command 'list-nodes' do |c|
    #   cli_syntax(c)
    #   c.summary = 'Return all the available nodes'
    #   action(c, Commands::List, method: :nodes)
    # end

    # command 'list-groups' do |c|
    #   cli_syntax(c)
    #   c.summary = 'Return all the available groups'
    #   action(c, Commands::List, method: :groups)
    # end

    # command 'template' do |c|
    #   cli_syntax(c)
    #   c.summary = 'View and manage a template resource'
    #   c.sub_command_group = true
    # end

    # command 'template show' do |c|
    #   cli_syntax(c, 'NAME')
    #   c.summary = 'View the content of a template'
    #   action(c, Commands::Template, method: :show)
    # end

    # command 'template create' do |c|
    #   cli_syntax(c, 'NAME [FILE_PATH]')
    #   c.summary = 'Upload a new template with a defined name'
    #   c.description = <<~DESC.chomp
    #     Create a new template entry from an existing file. The NAME
    #     must be alphanumeic but may contain: '.', '-', and '_'.
    #     File extensions are not treated as part of the NAME and
    #     can be ommitted.

    #     The FILE_PATH maybe absolute or relative to the current working
    #     directory. An empty file is uploaded if it is omitted.
    #   DESC
    #   action(c, Commands::Template, method: :create)
    # end

    # command 'template update' do |c|
    #   cli_syntax(c, 'NAME PATH')
    #   c.summary = 'Replace a template with a local file'
    #   action(c, Commands::Template, method: :update)
    # end

    # command 'template edit' do |c|
    #   cli_syntax(c, 'NAME')
    #   c.summary = 'Edit a template through the system edittor'
    #   action(c, Commands::Template, method: :edit)
    # end

    # command 'template delete' do |c|
    #   cli_syntax(c, 'NAME')
    #   c.summary = 'Permanently destroy a template'
    #   action(c, Commands::Template, method: :delete)
    # end

    # command 'download' do |c|
    #   cli_syntax(c, 'NAME[,NAME,..]')
    #   c.summary = 'Download the rendered files from the server'
    #   c.description = <<~DESC.chomp
    #     Download the rendered files for the given templates and contexts.
    #     Multiple templates can be selected by repeating the NAME argument. The
    #     NAME argument should match a template (see: 'template create --help').
    #     Multiple templates can be rendered by repeating the NAME argument as a
    #     comma separated list.

    #     All downloads are contextually dependent and must specify one of the
    #     cluster/group/node flags. Nothing will be downloaded without one of these
    #     flags as the context is required.

    #     By default all files are downloaded to subdirectories within the current
    #     working directory. The name of the subdirectories depends on the context:
    #       - cluster:  ./cluster
    #       - groups:   ./groups/<group-name>
    #       - nodes:    ./nodes/<node-name>
    #   DESC
    #   c.option '-n', '--nodes NODE_NAME[,NODE_NAME,..]',
    #     'Render the templates in the nodes context'
    #   c.option '-g', '--groups NODE_NAME[,NODE_NAME,..]',
    #     'Render the templates in the groups context'
    #   c.option '-N', '--nodes-in GROUP_NAME,[GROUP_NAME,..]',
    #     'Render the templates for all the node contexts within the given groups'
    #   c.option '-c', '--cluster', 'Render the templates in the cluster context'
    #   c.option '-o', '--output DIRECTORY',
    #     'Specify the directory to save the templates in'
    #   c.option '--force', 'Replace any existing file downloads'
    #   action(c, Commands::Download)
    # end
  end
end

