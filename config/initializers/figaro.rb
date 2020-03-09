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

require 'figaro'

# Loads the configurations into the environment
Figaro.application = Figaro::Application.new(
  environment: (ENV['RACK_ENV'] || 'development').to_sym,
  path: File.expand_path('../application.yaml', __dir__)
)
Figaro.load
      .reject { |_, v| v.nil? }
      .each { |key, value| ENV[key] ||= value }

# Hard sets the app's root directory to the current code base
ENV['app_root_dir'] = File.expand_path('../..', __dir__)
root_dir = ENV['app_root_dir']

relative_keys = ['topology_config', 'scripts_dir']
Figaro.require_keys(*['jwt_shared_secret',
                      'num_worker_commands',
                      'log_level',
                      *relative_keys].tap do |keys|
                        if ENV['remote_jwt']
                          keys << 'remote_url' << 'remote_cluster'
                        end
                      end)

# Sets relative keys from the install directory
# NOTE: Does not affect the path if it is already absolute
relative_keys.each { |k| ENV[k] = File.absolute_path(ENV[k], root_dir) }

