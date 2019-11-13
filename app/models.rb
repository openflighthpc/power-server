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
            transform_with: ->(node_hashes) do
              node_hashes.each_with_object(Hashie::Mash.new) do |(name, attr), memo|
                memo[id] = Node.new name: name,
                                    platform: attr.delete(:platform),
                                    attributes: attr.merge(name: name)
              end
            end

  # Converts the platform hash into Platform Objects
  property  :platforms, required: true, coerce: Hash[Symbol => Hash],
            transform_with: ->(plat_hashes) do
              plat_hashes.each_with_object(Hashie::Mash.new) do |(name, attr), memo|
                memo[name] = Platform.new(name: name, **attr)
              end
            end
end

class Node < Hashie::Dash
  include Hashie::Extensions::Dash::Coercion

  property :name,       required: true
  property :platform,   required: true
  property :attributes, required: true, coerce: Hashie::Mash
end

class Platform < Hashie::Dash
  include Hashie::Extensions::Dash::Coercion

  property  :name,      required: true
  property  :variables, default: []
  property  :power_on
  property  :power_off
  property  :reboot
  property  :status
  property  :status_off_exit_code,  default: 255
end

