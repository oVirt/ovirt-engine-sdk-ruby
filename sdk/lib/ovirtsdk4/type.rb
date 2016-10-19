#
# Copyright (c) 2016-2016 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module OvirtSDK4
  #
  # This module is a mixin that contains the methods common to struct and list types.
  #
  module Type
    #
    # Returns the value of the `href` attribute.
    #
    # @return [String]
    #
    def href
      @href
    end

    #
    # Sets the value of the `href` attribute.
    #
    # @param value [String]
    #
    def href=(value)
      @href = value
    end

    #
    # Returns the attribute corresponding to the given set of keys, but will not generate a `NoMethodError` when
    # the value corresponding to the key is `nil`, it will return `nil` instead. It is intended to simplify access
    # to deeply nested attributes within an structure, and mostly copied from the Ruby 2.3 `dig` method available
    # for hashes.
    #
    # For example, to access the alias of the first disk attached to a virtual machine that is part of an event without
    # having to check for `nil` several times:
    #
    # [source,ruby]
    # ----
    # event = ...
    # first_disk_id = event.dig(:vm, :disk_attachments, 0, :disk, :alias)
    # ----
    #
    # Which is equivalent to this:
    #
    # [source,ruby]
    # ----
    # event = ...
    # first_disk_id = nil
    # vm = event.vm
    # if !vm.nil?
    #   disk_attachments = vm.disk_attachments
    #   if !disk_attachments.nil?
    #     first_disk_attachment = disk_attachments[0]
    #     if !first_disk_attachment.nil?
    #       disk = first_disk_attachment.disk
    #       if !disk.nil?
    #         first_disk_id = disk.id
    #       end
    #     end
    #   end
    # end
    # ----
    #
    # @param keys [Array<Symbol, Integer>] An array of symbols corresponding to attribute names of structs, or integers
    #   corresponding to list indexes.
    #
    def dig(*keys)
      current = self
      keys.each do |key|
        if key.is_a?(Symbol)
          current = current.send(key)
        elsif key.is_a?(Integer)
          current = current[key]
        else
          raise TypeError, "The key '#{key}' isn't a symbol or integer"
        end
        break if current.nil?
      end
      current
    end
  end

  #
  # This is the base class for all the struct types.
  #
  class Struct
    include Type

    #
    # Empty constructor.
    #
    def initialize(opts = {})
      self.href = opts[:href]
    end

    #
    # Returns `true` if `self` and `other` have the same attributes and values.
    #
    def ==(other)
      !other.nil? && self.class == other.class
    end

    #
    # Use the same logic for `eql?` and `==`.
    #
    alias eql? ==

    #
    # Generates a hash value for this object.
    #
    def hash
      0
    end
  end

  #
  # This is the base class for all the list types.
  #
  class List < Array
    include Type
  end
end
