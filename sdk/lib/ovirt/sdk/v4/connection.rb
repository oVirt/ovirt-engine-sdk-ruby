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

require 'curb'
require 'uri'

module Ovirt
  module SDK
    module V4

      ##
      # This class is responsible for managing an HTTP connection to the engine server. It is intended as the entry
      # point for the SDK, and it provides access to the `system` service and, from there, to the rest of the services
      # provided by the API.
      #
      class Connection

        ##
        # Creates a new connection to the API server.
        #
        # This method supports the following parameters, provided as an optional hash:
        #
        # `:url` - The URL of the server, usually something like `https://server.example.com/ovirt-engine/api`.
        #
        # `:username` - The name of the user, something like `admin@internal`.
        #
        # `:password` - The name password of the user.
        #
        # `:insecure` - A boolean flag that indicates if the server TLS certificate and host name should be
        # checked. The default is `true`.
        #
        # `:ca_file` - A PEM file containing the trusted CA certificates. The certificate presented by the server
        # will be verified using these CA certificates.
        #
        # `:debug` - A boolean flag indicating if debug output should be generated. If the values is `true` all the
        # data sent to and received from the server will be written to `$stdout`. Be aware that user names and
        # passwords will also be written, so handle it with care. The default values is `false`.
        #
        def initialize(opts = {})
          # Get the values of the parameters and assign default values:
          url = opts[:url]
          username = opts[:username]
          password = opts[:password]
          insecure = opts[:insecure] || false
          ca_file = opts[:ca_file]
          debug = opts[:debug] || false

          # Check mandatory parameters:
          if url.nil?
             raise ArgumentError.new("The \"url\" parameter is mandatory.")
          end

          # Save the URL:
          @url = URI(url)

          # Create the cURL handle:
          @curl = Curl::Easy.new

          # Configure cookies so that they are enabled but stored only in memory:
          @curl.enable_cookies = true
          @curl.cookiefile = '/dev/null'
          @curl.cookiejar = '/dev/null'

          # Configure authentication:
          @curl.http_auth_types = :basic
          @curl.username = username
          @curl.password = password

          # Configure TLS parameters:
          if @url.scheme == 'https'
            if insecure
              @curl.ssl_verify_peer = false
              @curl.ssl_verify_host = false
            elsif ca_file.nil?
              raise ArgumentError.new("The \"ca_file\" argument is mandatory when using TLS.")
            elsif not ::File.file?(ca_file)
              raise ArgumentError.new("The CA file \"#{ca_file}\" doesn't exist.")
            else
              @curl.cacert = ca_file
            end
          end

          # Configure debug mode:
          if debug
            @curl.verbose = true
            @curl.on_debug do |type, data|
              case type
              when Curl::CURLINFO_DATA_IN
                prefix = '< '
              when Curl::CURLINFO_DATA_OUT
                prefix = '> '
              when Curl::CURLINFO_HEADER_IN
                prefix = '< '
              when Curl::CURLINFO_HEADER_OUT
                prefix = '> '
              else
                prefix = '* '
              end
              lines = data.gsub("\r\n", "\n").strip.split("\n")
              lines.each do |line|
                puts prefix + line
              end
            end
          end

        end

        ##
        # Returns the reference to the root of the services tree.
        #
        # The returned value is an instance of the Ovirt::SDK::V4::SystemService class.
        #
        def system
          @system ||= SystemService.new(self, "")
          return @system
        end

        ##
        # Performs an HTTP request.
        #
        # This method is intended for internal use by other components of the SDK, refrain from using it directly, as
        # backwards compatibility isn't guaranteed.
        #
        # This method supports the following parameters, provided as an optional hash:
        #
        # `:method` - The HTTP method to execute. The value should be `:GET`, `:POST`, `:PUT`, `:DELETE` or
        # `:HEAD`.
        #
        # `:path` - The path that will be added to the URL used when the connection was created. For example, of the
        # connection was created with `https://engine.example.com/ovirt-engine/api` and the value of `:path` is
        # `vms/123` then the request will be sent to `https://engine.example.com/ovirt-engine/api/vms/123`.
        #
        # `:headers` - A hash containing the HTTP headers to add to the request. The keys of the hash should be
        # strings containing the names of the headers, and the values should be strings containing the
        # values. The default is an empty hash.
        #
        # `:query` - A hash containing the query parameters to add to the request. The keys of the hash should be
        # strings containing the names of the parameters, and the values should be strings containing the values. The
        # default is an empty hash.
        #
        # `:matrix` - A hash containing the matrix parameters to add to the request. The keys of the hash should be
        # strings containing the names of the parameters, and the values should be strings containing the values. The
        # default is an empty hash.
        #
        # `:body` - A string containing the request body.
        #
        # `:last` - Boolean flag indicating if this is the last request of a session. This will disable the use of
        # the `Prefer: persistent-auth` header, thus indicating to the server that the session should be closed.
        # The default is `false`.
        #
        # `:persistent_auth` - Boolean flag indicating if persistent authentication based on cookies should be used.
        # The default is `true`.
        #
        # The returned value is an string containing the HTTP response body.
        #
        def request(opts = {})
          # Get the values of the parameters and assign default values:
          method = opts[:method]
          path = opts[:path]
          headers = opts[:headers] || {}
          query = opts[:query] || {}
          matrix = opts[:matrix] || {}
          body = opts[:body] || {}
          last = opts[:last] || false
          persistent_auth = opts[:persistent_auth] || true

          # Build the URL:
          url = self.class.build_url({
            :base => @url.to_s,
            :path => path,
            :query => query,
            :matrix => matrix,
          })
          @curl.url = url

          # Add headers, avoiding those that have no value:
          @curl.headers.clear
          @curl.headers.merge!(headers)
          @curl.headers['Content-Type'] = 'application/xml'
          @curl.headers['Accept'] = 'application/xml'

          # Every request except the last one should indicate that we prefer
          # to use persistent authentication:
          if persistent_auth and not last
            @curl.headers['Prefer'] = 'persistent-auth'
          end

          # Send the request and wait for the response:
          case method
          when :DELETE
            @curl.http_delete
          when :GET
            @curl.http_get
          when :PUT
            @curl.http_put(body)
          when :HEAD
            @curl.http_head
          when :POST
            @curl.http_post(body)
          end

          # Return the response body:
          return @curl.body_str
        end

        ##
        # Releases the resources used by this connection.
        #
        def close
          # Send the last request to indicate the server that the session should be closed:
          request({:method => :HEAD, :path => '', :last => true})

          # Release resources used by the cURL handle:
          @curl.close
        end

        ##
        # Builds a request URL from a base URL, a path, and the sets of matrix and query parameters.
        #
        # This method supports the following parameters, provided as an optional hash:
        #
        # `:base` - The base URL.
        #
        # `:path` - The path that will be added to the base URL.
        #
        # `:query` - A hash containing the query parameters to add to the URL. The keys of the hash should be strings
        # containing the names of the parameters, and the values should be strings containing the values. The default
        # is an empty hash.
        #
        # `:matrix` - A hash containing the matrix parameters to add to the URL. The keys of the hash should be strings
        # containing the names of the parameters, and the values should be strings containing the values. The default
        # is an empty hash.
        #
        # The returned value is an string containing the URL.
        #
        def self.build_url(opts = {})
          # Get the values of the parameters and assign default values:
          base = opts[:base]
          path = opts[:path] || ''
          query = opts[:query] || {}
          matrix = opts[:matrix] || {}

          # Add the path and the parameters:
          url = base + path
          if not matrix.empty?
            matrix.each do |key, value|
              url = url + ';' + URI.encode_www_form({key => value})
            end
          end
          if not query.empty?
            url = url + '?' + URI.encode_www_form(query)
          end
          return url
        end

      end

    end
  end
end
