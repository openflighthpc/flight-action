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

module JsonApiClient
  class Resource

    protected

    def error_message_for(error)
      error.error_msg(prefer_details: true)
    end
  end

  class ErrorCollector < Array
    class Error
      def error_msg(prefer_details: false)
        msg = if prefer_details
                detail || title || "invalid"
              else
                title || detail || "invalid"
              end
        if source_parameter
          "#{source_parameter} #{msg}"
        else
          msg
        end
      end
    end
  end
end
