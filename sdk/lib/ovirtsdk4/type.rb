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
      return @href
    end

    #
    # Sets the value of the `href` attribute.
    #
    # @param value [String]
    #
    def href=(value)
      @href = value
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

  end

  #
  # This is the base class for all the list types.
  #
  class List < Array
    include Type
  end

end
