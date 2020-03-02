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

task :require do
  $: << File.expand_path('lib', __dir__)
  ENV['BUNDLE_GEMFILE'] ||= File.join(__dir__, 'Gemfile')

  require 'rubygems'
  require 'bundler/setup'

  require 'active_support/core_ext/string'
  require 'active_support/core_ext/module'
  require 'active_support/core_ext/module/delegation'


  require 'action_client/config'

  if ActionClient::Config::Cache.debug?
    require 'pry'
    require 'pry-byebug'
  end

  require 'action_client/cli'
end

task console: :require do
  require 'pry'
  require 'pry-byebug'
  binding.pry
end

