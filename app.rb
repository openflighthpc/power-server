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

require 'json'
require 'jsonapi-serializers'
require 'sinatra'
require "sinatra/json"
require "sinatra/namespace"

BEARER_REGEX    = /\ABearer\s(?<token>.*)\Z/
SINGLE_REGEX    = /[[:alnum:]]+(\[\d+(-\d+)\])?/
NODEATTR_REGEX  = /\A(#{SINGLE_REGEX}(,#{SINGLE_REGEX})*)?\Z/

configure do
  set :show_exceptions, :after_handler
  set :logger, DEFAULT_LOGGER
  enable :logging
end

helpers do
  include Pundit

  # Override Authorize to require two arguments. Single argument mode is only
  # supported by rails
  def authorize(record, query)
    super
  end

  def token
    BEARER_REGEX.match(env['HTTP_AUTHORIZATION'] || '')&.named_captures&.[]('token')
  end

  def pundit_user
    Token.from_jwt(token || '')
  end

  def serialize_models(models, options = {})
    options[:is_collection] = true
    JSONAPI::Serializer.serialize(models, options).tap do |result|
      result['data'].each { |model| model.delete('links') }
    end
  end
end

error Pundit::NotAuthorizedError do
  status 403
  body "Forbidden"
end

error JsonApiClient::Errors::AccessDenied do
  status 502
  body 'Invalid upstream server configuration'
end

error JsonApiClient::Errors::ConnectionError do
  status 504
  body 'Failed to contact the upstream server'
end

before do
  authorize :command, :valid?
end

# Basic get methods to list the available nodes/groups that service can manage
get('/nodes') do
  json serialize_models(Topology::Cache.nodes.to_a)
end

namespace '/' do
  helpers do
    def nodes_param
      if match = NODEATTR_REGEX.match(params[:nodes] || '')
        match.to_s
      else
        halt 400, 'Unrecognised nodes syntax'
      end
    end

    def names_from_nodes_param
      nodes_param.split(',')
                 .map { |n| Nodeattr.explode(n) }
                 .flatten
                 .uniq
    end

    def groups_param
      if match = NODEATTR_REGEX.match(params[:groups] || '')
        match.to_s
      else
        halt 400, 'Unrecognised groups syntax'
      end
    end

    def names_from_groups_param
      groups_param.split(',')
                  .map { |n| Nodeattr.explode(n) }
                  .flatten
                  .uniq
    end

    def nodes
      single_nodes = names_from_nodes_param.map { |n| Topology::Cache.nodes[n] }
      group_nodes = names_from_groups_param.map { |g| Topology::Cache.nodes.where_group(g) }
      [single_nodes, group_nodes].flatten.uniq
    end

    def commands(action)
      Commands.new(action, nodes).tap { |c| c.run_in_parallel(logger) }.commands
    end
  end

  get     { json serialize_models(commands(:status)) }
  patch   { json serialize_models(commands(:power_on)) }
  put     { json serialize_models(commands(:restart)) }
  delete  { json serialize_models(commands(:power_off)) }
end

