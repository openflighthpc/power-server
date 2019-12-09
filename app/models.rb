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

require 'hashie'

class SymbolizedMash < ::Hashie::Mash
  include Hashie::Extensions::Mash::SymbolizeKeys
end

class Topology < Hashie::Trash
  module Cache
    class << self
      delegate_missing_to :cache

      def cache
        @cache ||= Topology.new(SymbolizedMash.load(path))
      end

      def path
        Figaro.env.topology_config
      end
    end
  end

  include Hashie::Extensions::Dash::Coercion

  # Converts the nodes hash into Node objects
  property  :nodes, required: true, coerce: Hash[Symbol => Hash],
            transform_with: ->(h) { Nodes.new(h) }

  # Converts the platform hash into Platform Objects
  property  :platforms, required: true, coerce: Hash[Symbol => Hash],
            transform_with: ->(h) { Platforms.new(h) }
end

class Nodes < Hashie::Mash
  def initialize(**node_hash)
    nodes = node_hash.map do |name, attr|
      node = Node.new name: name,
                      platform: attr.delete(:platform),
                      attributes: attr.merge(name: name)
      [name, node]
    end
    super(nodes.to_h)
  end

  def [](key)
    super(key) || Node.new(name: key, attributes: { name: key }, missing: true)
  end
end

class Node < Hashie::Dash
  include Hashie::Extensions::Dash::Coercion

  property :name,       required: true
  property :missing,    default: false
  property :platform,   default: :missing
  property :attributes, required: true, coerce: Hashie::Mash

  def missing?
    missing
  end
end

class Platforms < Hashie::Mash
  def initialize(**platform_hash)
    platforms = platform_hash.merge(missing: {}).map do |name, attr|
      [name, Platform.new(name: name, **attr)]
    end
    super(platforms.to_h)
  end

  def [](key)
    super(key) || super(:missing)
  end
end

class Platform < Hashie::Dash
  include Hashie::Extensions::Dash::Coercion

  property  :name,      required: true
  property  :variables, default: []
  property  :power_on,  default: 'exit 1'
  property  :power_off, default: 'exit 1'
  property  :restart,   default: 'exit 1'
  property  :status,    default: 'exit 1'
  property  :status_off_exit_code,  default: 255
end

