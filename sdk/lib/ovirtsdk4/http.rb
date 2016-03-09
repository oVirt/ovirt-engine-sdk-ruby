#--
# Copyright (c) 2015-2016 Red Hat, Inc.
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
#++

require 'curb'
require 'uri'

module OvirtSDK4

  ##
  # This class represents an HTTP request.
  #
  # @api private
  #
  class Request
    attr_accessor :method
    attr_accessor :path
    attr_accessor :matrix
    attr_accessor :query
    attr_accessor :headers
    attr_accessor :body

    ##
    # Creates a new HTTP request.
    #
    def initialize(opts = {})
      self.method = opts[:method] || :GET
      self.path = opts[:path] || ''
      self.headers = opts[:headers] || {}
      self.matrix = opts[:matrix] || {}
      self.query = opts[:query] || {}
      self.body = opts[:body]
    end

  end

  ##
  # This class represents an HTTP response.
  #
  # @api private
  #
  class Response
    attr_accessor :body
    attr_accessor :code
    attr_accessor :headers
    attr_accessor :message

    ##
    # Creates a new HTTP response.
    #
    def initialize(opts = {})
      self.body = opts[:body]
      self.code = opts[:code]
      self.headers = opts[:headers]
      self.message = opts[:message]
    end
  end

  ##
  # This class is responsible for managing an HTTP connection to the engine server. It is intended as the entry
  # point for the SDK, and it provides access to the `system` service and, from there, to the rest of the services
  # provided by the API.
  #
  class Connection

    ##
    # Creates a new connection to the API server.
    #
    # @param opts [Hash] The options used to create the connection.
    #
    # @option opts [String] :url A string containing the base URL of the server, usually something like
    #   `\https://server.example.com/ovirt-engine/api`.
    #
    # @option opts [String] :user The name of the user, something like `admin@internal`.
    #
    # @option opts [String] :password The password of the user.
    #
    # @option opts [Boolean] :insecure (true) A boolean flag that indicates if the server TLS certificate and host
    #   name should be checked.
    #
    # @option opts [String] :ca_file The name of a a PEM file containing the trusted CA certificates. The certificate
    #   presented by the server will be verified using these CA certificates.
    #
    # @option opts [Boolean] :debug (false) A boolean flag indicating if debug output should be generated. If the
    #   values is `true` all the data sent to and received from the server will be written to `$stdout`. Be aware that
    #   user names and passwords will also be written, so handle it with care.
    #
    # @option opts [String, IO] :log The log file where the debug output will be written. The value can be an string
    #   containing a file name or an IO object. If it is a file name then the file will be created if it doesn't
    #   exist, and the debug output will be added to the end. The file will be closed when the connection is closed.
    #   If it is an IO object then the debug output will be written directly, and it won't be closed.
    #
    def initialize(opts = {})
      # Get the values of the parameters and assign default values:
      url = opts[:url]
      username = opts[:username]
      password = opts[:password]
      insecure = opts[:insecure] || false
      ca_file = opts[:ca_file]
      debug = opts[:debug] || false
      log = opts[:log] || STDOUT

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
        if log.is_a?(String)
          @log = ::File.open(log, 'a')
        else
          @log = log
        end
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
            @log.puts(prefix + line)
          end
          @log.flush
        end
      end

    end

    ##
    # Returns the base URL of this connection.
    #
    # @return [String]
    #
    def url
      return @url
    end

    ##
    # Returns a reference to the root of the services tree.
    #
    # @return [SystemService]
    #
    def system_service
      @system_service ||= SystemService.new(self, "")
      return @system_service
    end

    ##
    # Returns a reference to the service corresponding to the given path. For example, if the `path` parameter
    # is `vms/123/disks` then it will return a reference to the service that manages the disks for the virtual
    # machine with identifier `123`.
    #
    # @param path [String] The path of the service, for example `vms/123/disks`.
    # @return [Service]
    # @raise [Error] If there is no service corresponding to the given path.
    #
    def service(path)
      return system_service.service(path)
    end

    ##
    # Sends an HTTP request and waits for the response.
    #
    # @param request [Request] The Request object containing the details of the HTTP request to send.
    # @param last [Boolean] A boolean flag indicating if this is the last request.
    # @return [Response] A request object containing the details of the HTTP response received.
    #
    # @api private
    #
    def send(request, last = false)
      # Build the URL:
      @curl.url = build_url({
        :path => request.path,
        :query => request.query,
        :matrix => request.matrix,
      })

      # Add headers, avoiding those that have no value:
      @curl.headers.clear
      @curl.headers.merge!(request.headers)
      @curl.headers['User-Agent'] = "RubySDK/#{VERSION}"
      @curl.headers['Version'] = '4'
      @curl.headers['Content-Type'] = 'application/xml'
      @curl.headers['Accept'] = 'application/xml'

      # All requests except the last one should indicate that we want to use persistent authentication:
      if !last
        @curl.headers['Prefer'] = 'persistent-auth'
      end

      # Send the request and wait for the response:
      case request.method
      when :DELETE
        @curl.http_delete
      when :GET
        @curl.http_get
      when :PUT
        @curl.http_put(request.body)
      when :HEAD
        @curl.http_head
      when :POST
        @curl.http_post(request.body)
      end

      # Return the response:
      response = Response.new
      response.body = @curl.body_str
      response.code = @curl.response_code
      return response
    end

    ##
    # Tests the connectivity with the server. If connectivity works correctly it returns `true`. If there is any
    # connectivity problem it will either return `false` or raise an exception if the `raise_exception` parameter is
    # `true`.
    #
    # @param raise_exception [Boolean]
    # @return [Boolean]
    #
    def test(raise_exception = false)
      begin
        system_service.get
        return true
      rescue Exception
        raise if raise_exception
        return false
      end
    end

    ##
    # Releases the resources used by this connection.
    #
    def close
      # Send the last request to indicate the server that the session should be closed:
      request = Request.new({
        :method => :HEAD,
      })
      send(request, true)

      # Close the log file, if we did open it:
      unless @log.nil? || @log.equal?(STDOUT)
        @log.close
      end

      # Release resources used by the cURL handle:
      @curl.close
    end

    ##
    # Builds a request URL from a path, and the sets of matrix and query parameters.
    #
    # @params opts [Hash] The options used to build the URL.
    #
    # @option opts [String] :path The path that will be added to the base URL. The default is an empty string.
    #
    # @option opts [Hash<String, String>] :query ({}) A hash containing the query parameters to add to the URL. The
    #   keys of the hash should be strings containing the names of the parameters, and the values should be strings
    #   containing the values.
    #
    # @option opts [Hash<String, String>] :matrix ({}) A hash containing the matrix parameters to add to the URL. The
    #   keys of the hash should be strings containing the names of the parameters, and the values should be strings
    #   containing the values.
    #
    # @return [String] The URL.
    #
    # @api private
    #
    def build_url(opts = {})
      # Get the values of the parameters and assign default values:
      path = opts[:path] || ''
      query = opts[:query] || {}
      matrix = opts[:matrix] || {}

      # Add the path and the parameters:
      url = @url.to_s + path
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
