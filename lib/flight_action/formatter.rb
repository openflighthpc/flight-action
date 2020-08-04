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

module FlightAction
  class Formatter
    def initialize(jobs:, streams: %w(stdout stderr), output_dir:, prefix:)
      @jobs = jobs
      @streams = streams
      @output_dir = output_dir
      @prefix = prefix
    end

    def run
      @jobs.each do |job|
        persist_output(job) if @output_dir
        print_tagged_streams(job)
      end
    end

    def print_tagged_streams(job)
      Array.wrap(@streams).each do |stream|
        lines = tagged_lines(job, stream)
        io_for_stream(stream).puts lines.join unless lines.empty?
      end
    end

    def tagged_lines(job, stream)
      return job.send(stream).lines unless @prefix

      tag = job.node.id
      job.send(stream).lines.map do |line|
        "#{tag}: #{line}"
      end
    end

    def persist_output(job)
      FileUtils.mkdir_p(@output_dir)

      # Save Status
      path = File.expand_path("#{job.node.id}.status", @output_dir)
      File.write(path, job.status)

      # Save Stdout
      path = File.expand_path("#{job.node.id}.stdout", @output_dir)
      File.write(path, job.stdout)

      # Save Stderr
      path = File.expand_path("#{job.node.id}.stderr", @output_dir)
      File.write(path, job.stderr)
    end

    def io_for_stream(stream)
      Kernel.const_get(stream.to_s.upcase)
    rescue NameError
      STDOUT
    end
  end
end