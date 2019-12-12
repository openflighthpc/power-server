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

require 'json_api_client'

class Record < JsonApiClient::Resource
  self.site = Figaro.env.remote_url
  self.connection.faraday.authorization :Bearer, Figaro.env.remote_jwt
  connection.use Faraday::Response::Logger, DEFAULT_LOGGER, { bodies: true } do |logger|
    logger.filter(/(Authorization:)(.*)/, '\1 [REDACTED]')
  end
end

class NodeRecord < Record
  def self.resource_name
    'nodes'
  end

  belongs_to :group, class_name: 'GroupRecord', shallow_path: true

  property :name, type: :string
  property :params, type: :hash
end

class GroupRecord < Record
  def self.resource_name
    'groups'
  end
end

