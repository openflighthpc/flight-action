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

require 'json_api_client'

module FlightAction
  class BaseRecord < JsonApiClient::Resource
    def self.inherited(klass)
      resolve_custom_type klass.resource_name, klass
    end

    def self.resource_name
      @resource_name ||= self.to_s.demodulize.chomp('Record').downcase.pluralize
    end

    # Overridden to add `compact` call to paths prior to joining them.
    # Without this multiple shallow belongs_to assocations don't work when the
    # base_url contains a path part.
    def self._set_prefix_path(attrs)
      paths = _belongs_to_associations.map do |a|
        a.set_prefix_path(attrs, route_formatter)
      end

      paths.compact.join("/")
    end

    self.site = Config::Cache.base_url
  end

  BaseRecord.connection_options[:status_handlers] = {
    404 => ->(env) { raise FlightAction::NotFound, env },
    502 => ->(env) { raise FlightAction::ConnectionError },
  }

  BaseRecord.connection do |connection|
    connection.use Faraday::Response::Logger if ENV.fetch('DEBUG', false)
    connection.faraday.authorization :Bearer, Config::Cache.jwt_token
    connection.faraday.ssl.verify = Config::Cache.verify_ssl?
  end

  class NodeRecord < BaseRecord
    property :name
  end

  class GroupRecord < BaseRecord
    property :name
  end

  class CommandRecord < BaseRecord
    property :name
    property :summary
    property :description
    property :syntax
    property :confirmation
  end

  class JobRecord < BaseRecord
    property :stdout
    property :stderr
    property :status

    belongs_to :node, shallow_path: true
    belongs_to :ticket, shallow_path: true
  end

  class TicketRecord < BaseRecord
    belongs_to :command, shallow_path: true
    belongs_to :context, shallow_path: true
    has_many :nodes
    has_many :jobs
  end
end

