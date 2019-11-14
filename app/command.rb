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

Command = Struct.new(:action, :node) do
  extend Memoist

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
                   .map { |v| "#{v}=\"#{node.attributes[v]}\"" }
                   .join("\n")
    <<~CMD
      # Configuration Parameters For: #{node.name}
      #{args}

      # Command For: #{node.platform}##{action}
      #{platform[action]}
    CMD
  end
  memoize :cmd

  def platform
    Topology::Cache.platforms[node.platform]
  end
  memoize :platform

  def capture2e
    Open3.capture2e(cmd)
  end
  memoize :capture2e

  def exit_code
    capture2e.last.to_i
  end

  def stdout_and_stderr
    capture2e.first
  end
end

