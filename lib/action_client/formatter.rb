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

module ActionClient
  class Formatter
    def initialize(jobs, mode, output_dir)
      @jobs = jobs
      @mode = mode
      @output_dir = output_dir
    end

    def run
      @jobs.each do |job|
        if @output_dir
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

        case @mode
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
    end
  end
end
