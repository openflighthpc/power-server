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

module HasPowerRoutes
  extend ActiveSupport::Concern

  class_methods do
    def path
      raise NotImplementedError
    end
  end

  included do
    configure do
      mime_type :api_json, 'application/vnd.api+json'
    end

    helpers do
      def topology
        Topology::Cache
      end

      def serialize_models(models, options = {})
        options[:is_collection] = true
        JSONAPI::Serializer.serialize(models, options).tap do |result|
          result['data'].each { |model| model.delete('links') }
        end
      end
    end

    before do
      # content_type :api_json
    end

    get(path)     { serialize_models(commands(:status)).to_json }
    patch(path)   { serialize_models(commands(:power_on)).to_json }
    delete(path)  { serialize_models(commands(:power_off)).to_json }
  end

  def node_names
    raise NotImplementedError
  end

  def nodes
    node_names.map { |n| topology.nodes[n] }.reject(&:nil?)
  end

  def commands(action)
    nodes.map { |n| Command.new(action, n) }
  end
end

class NodeController < Sinatra::Base
  def self.path
    /\/(?<nodeattr_str>[[:alnum:]]+)/
  end

  def node_names
    [params['nodeattr_str']]
  end

  # Must be included AFTER path has been defined
  include HasPowerRoutes
end

