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

task :require do
  $: << File.expand_path('lib', __dir__)
  ENV['BUNDLE_GEMFILE'] ||= File.join(__dir__, 'Gemfile')

  require 'rubygems'
  require 'bundler/setup'

  require 'active_support/core_ext/string'
  require 'active_support/core_ext/module'
  require 'active_support/core_ext/module/delegation'


  require 'flight_action/config'

  if FlightAction::Config::Cache.debug?
    require 'pry'
    require 'pry-byebug'
  end

  require 'flight_action/patches'
  require 'flight_action/errors'
  require 'flight_action/formatter'
  require 'flight_action/records'
  require 'flight_action/cli'
end

task console: :require do
  require 'pry'
  require 'pry-byebug'
  binding.pry
end

