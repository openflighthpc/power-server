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
require "sinatra/json"

module HasPowerRoutes
  extend ActiveSupport::Concern

  BEARER_REGEX = /\ABearer\s(?<token>.*)\Z/

  class_methods do
    def path
      raise NotImplementedError
    end
  end

  included do
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

    configure do
      set :show_exceptions, :after_handler
    end

    helpers do
      def serialize_models(models, options = {})
        options[:is_collection] = true
        JSONAPI::Serializer.serialize(models, options).tap do |result|
          result['data'].each { |model| model.delete('links') }
        end
      end
    end

    before do
      authorize :command, :valid?
    end

    error Pundit::NotAuthorizedError do
      status 403
      body "Forbidden"
    end

    get(path)     { json serialize_models(commands(:status)) }
    patch(path)   { json serialize_models(commands(:power_on)) }
    delete(path)  { json serialize_models(commands(:power_off)) }
  end

  def node_names
    raise NotImplementedError
  end

  def nodes
    node_names.map { |n| Topology::Cache.nodes[n] }
  end

  def commands(action)
    Commands.new(action, nodes).tap(&:run_in_parallel).commands
  end
end

class NodeController < Sinatra::Base
  def self.path
    /\/(?<nodeattr_str>[[:alnum:]]+(?:%5B\d+(?:-\d+)?%5D)?)/
  end

  def node_names
    Nodeattr.explode_nodes(params['nodeattr_str'].sub('%5B', '[').sub('%5D', ']'))
  end

  # Must be included AFTER path has been defined
  include HasPowerRoutes
end

