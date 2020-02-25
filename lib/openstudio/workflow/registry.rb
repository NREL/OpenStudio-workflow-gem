# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER, THE UNITED STATES
# GOVERNMENT, OR ANY CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

module OpenStudio
  module Workflow
    # Registers objects in a single place. Based on Hashicorps's Vagrant Registry class
    #
    # This allows certain components (such as models, weather files, proxy settings, etc.) to be registered as blocks
    #   and lazily updated. This allows for the state of various objects to be updated through evaluation of or
    #   overwriting the key. An instance of this class is passed between jobs to allow for highly flexible workflow
    #   definitions. Note that hashes can be passed into the registry as follows: hash = {...};
    #   Registry.new.register(:hash) { hash } or Registry.new.register(:hash) { {...} }. This class will likely absorb
    #   un-abstracted elements of the adapter class, see Workflow#Adapter

    # @todo (rhorsey) registry should be a member of WorkflowRunner - DLM
    # @todo (rhorsey) how is this different than a regular hash?  why is it important to be able to register keys with blocks that return values instead of values, looks like the block is called on insert anyway? let's not go crazy on performance optimizations until we have to - DLM
    class Registry
      def initialize
        @items = {}
        @results_cache = {}
      end

      # Register a key and cache it's value. Note that if a key with the given name already exists it is overwritten
      #
      # @param [] key The key for the passed in block. Symbols are highly recommended
      # @param [Proc] block The block (Proc) which contains the registered information
      # @return [] Returns block.call from the registries cache
      #
      def register(key, &block)
        raise ArgumentError, 'block required' unless block_given?
        @items[key] = block
        @results_cache[key] = @items[key].call
      end

      # Get the cached value of the given key
      #
      # @param [] key  The key defining the block
      # @return [] Returns the registries cached value for the key or nil if the key was not found
      #
      def get(key)
        return nil unless @items.key?(key)
        @results_cache[key]
      end
      alias [] get

      # Re-evaluate the proc of a key and update the cache
      #
      # @param [Sym or String] key This will evaluate the item assigned to the key and update the cache if possible
      # @return [] If successful the method returns the new value, and if it cannot find or cannot update the key it
      #   returns nil
      #
      def eval(key)
        return nil unless @items.key?(key)
        begin
          @items[key].call
        rescue
          return nil
        end
        @results_cache[key] = @items[key].call
      end

      # Checks if the given key is registered with the registry
      #
      # @return [Boolean]
      #
      def key?(key)
        @items.key?(key)
      end
      alias has_key? key?

      # Returns an array populated with the keys of this object
      #
      # @return [Array]
      #
      def keys
        @items.keys
      end

      # Return the number of elements in this registry
      #
      # @return [Fixnum]
      #
      def length
        @items.keys.length
      end
      alias size length

      # Checks if this registry has any items
      #
      # @return [Boolean]
      #
      def empty?
        @items.keys.empty?
      end

      # Merge one registry with another and return a completely new registry. Note that the result cache is completely
      #   busted, so any gets on the new registry will result in a cache miss
      #
      # @param [Registry] other The other #Registry to merge onto of self
      # @return [Registry] A merged #Registry
      #
      def merge(other)
        self.class.new.tap do |result|
          result.merge!(self)
          result.merge!(other)
        end
      end

      # Like #merge but updates self
      #
      # @param [Registry] other The other #Registry to merge onto of self
      # @return [Void]
      #
      def merge!(other)
        @items.merge!(other.__internal_state[:items])
        self
      end

      # Converts the registry to a hash
      #
      # @return [Hash] The registry as a hash
      #
      def to_hash
        result = {}
        @results_cache.each_pair do |key, value|
          result[key] = value
        end

        result
      end

      def __internal_state
        {
          items: @items,
          results_cache: @results_cache
        }
      end
    end
  end
end
