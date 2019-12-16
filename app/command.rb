# frozen_string_literal: true

#==============================================================================
# Copyright (C) 2019-present Alces Flight Ltd.
#
# This file is part of Power Server.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# Power Server is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with Flight Cloud. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on Power Server, please visit:
# https://github.com/openflighthpc/power-server
#===============================================================================

require 'open3'
require 'memoist'
require 'parallel'
require 'shellwords'

Commands = Struct.new(:action, :nodes) do
  extend Memoist

  def commands
    nodes.map { |n| Command.new(action, n) }
  end
  memoize :commands

  def run_in_parallel(logger)
    Parallel.each(commands, in_threads: Figaro.env.num_worker_commands.to_i) do |cmd|
      if cmd.missing?
        logger.error "Could not locate node: #{cmd.node.name}"
      else
        cmd.log(logger)
      end
    end
  end
end

Command = Struct.new(:action, :node) do
  extend Memoist

  delegate :missing?, to: :node

  def self.working_dir
    Figaro.env.scripts_dir
  end

  def jsonapi_serializer_class_name
    if action == :status
      StatusCommandSerializer
    else
      CommandSerializer
    end
  end

  def id
    node.name.to_s
  end

  def cmd
    args = platform.variables
                   .map do |v|
                     "#{v}=\"#{Shellwords.escape(node.attributes[v])}\""
                   end.join("\n")
    <<~CMD
      # Working Directory:
      cd #{self.class.working_dir}

      # Configuration Parameters: #{node.name}
      #{args}

      # Run: #{node.platform}:#{action}
      #{
        [
          (action == :status ? "# Off Exit Code: #{platform.status_off_exit_code}" : nil),
          platform[action]
        ].reject(&:nil?).join("\n")
      }
    CMD
  end
  memoize :cmd

  def platform
    Topology::Cache.platforms[node.platform]
  end
  memoize :platform

  def capture3
    if missing?
      [nil, nil, nil]
    else
      Open3.capture3(cmd)
    end
  end
  memoize :capture3

  def exit_code
    capture3.last&.exitstatus
  end

  def stdout
    capture3.first
  end

  def stderr
    capture3[1]
  end

  def log(logger)
    msg = <<~MSG

      ## Command ##
      #{cmd}

      ## Exit Code ##
      #{ exit_code }

      ## STDOUT ##
      #{stdout}

      ## STDERR ##
      #{stderr}
    MSG
    exit_code == 0 ? logger.info(msg) : logger.error(msg)
  end
end

