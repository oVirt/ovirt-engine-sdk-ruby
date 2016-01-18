#--
# Copyright (c) 2015 Red Hat, Inc.
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
#++

module Ovirt
  module SDK
    module V4

      ##
      # This is the base class for all the struct types of the SDK. It contains the utility methods used by all of
      # them.
      #
      class Struct

        ##
        # Returns the value of the `href` attribute.
        #
        def href
          return @href
        end

        ##
        # Sets the value of the `href` attribute.
        #
        def href=(value)
          @href = value
        end

        ##
        # Returns the reference to the connection that created this object.
        #
        def connection
          return @connection
        end

        ##
        # Sets reference to the connection that created this object.
        #
        def connection=(value)
          @connection = value
        end

        ##
        # Indicates if this structure is used as a link. When a structure is used as a link only the identifier and the
        # `href` attributes will be returned by the server.
        #
        def is_link?
          return @is_link
        end

        ##
        # Sets the value of the flag that indicates if this structure is used as a link.
        #
        def is_link=(value)
          @is_link = value
        end

        ##
        # Follows the `href` attribute of this structure, retrieves the object and returns it.
        #
        def follow_link
          # Check that the "href" and "connection" attributes have values, as both are needed in order to retrieve
          # the representation of the object:
          if href.nil?
            raise Error.new("Can't follow link because the \"href\" attribute does't have a value")
          end
          if connection.nil?
            raise Error.new("Can't follow link because the \"connection\" attribute does't have a value")
          end

          # Check that the value of the "href" attribute is compatible with the base URL of the connection:
          prefix = connection.url.path
          if !prefix.end_with?('/')
            prefix += '/'
          end
          if !href.start_with?(prefix)
            raise Error.new("The URL \"#{href}\" isn't compatible with the base URL of the connection")
          end

          # Remove the prefix from the URL, follow the path to the relevant service and invoke the "get" method to
          # retrieve its representation:
          path = href[prefix.length..-1]
          service = connection.service(path)
          return service.get
        end

        ##
        # Empty constructor.
        #
        def initialize(opts = {})
          self.href = opts[:href]
          self.connection = opts[:connection]
          self.is_link = opts[:is_link]
        end

      end

    end
  end
end
