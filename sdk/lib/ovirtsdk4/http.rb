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
require 'json'
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
    # @option opts [Boolean] :insecure (false) A boolean flag that indicates if the server TLS certificate and host
    #   name should be checked.
    #
    # @option opts [String] :ca_file The name of a PEM file containing the trusted CA certificates. The certificate
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
    # @option opts [Boolean] :kerberos (false) A boolean flag indicating if Kerberos uthentication should be used
    #   instead of the default basic authentication.
    #
    # @option opts [Integer] :timeout (0) The maximun total time to wait for the response, in seconds. A value of zero
    #   (the default) means wait for ever. If the timeout expires before the response is received an exception will be
    #   raised.
    #
    # @option opts [Boolean] :compress (false) A boolean flag indicating if the SDK should ask the server to send
    #   compressed responses. Note that this is a hint for the server, and that it may return uncompressed data even
    #   when this parameter is set to `true`.
    #
    # @option opts [String] :sso_url A string containing the base SSO URL of the server, usually something like
    #   `\https://server.example.com/ovirt-engine/sso/oauth/token?`
    #   `\grant_type=password&scope=ovirt-app-api` for password authentication or
    #   `\https://server.example.com/ovirt-engine/sso/oauth/token-http-auth?`
    #   `\grant_type=urn:ovirt:params:oauth:grant-type:http&scope=ovirt-app-api` for kerberos authentication
    #   Default SSO url is computed from the `url` if no `sso_url` is provided.
    #
    # @option opts [Boolean] :sso_insecure A boolean flag that indicates if the SSO server TLS certificate and
    #    host name should be checked. Default is value of `insecure`.
    #
    # @option opts [String] :sso_ca_file The name of a PEM file containing the trusted CA certificates. The
    #   certificate presented by the SSO server will be verified using these CA certificates. Default is value of
    #   `ca_file`.
    #
    # @option opts [Boolean] :sso_debug A boolean flag indicating if SSO debug output should be generated. If the
    #   values is `true` all the data sent to and received from the SSO server will be written to `$stdout`. Be aware
    #   that user names and passwords will also be written, so handle it with care. Default is value of `debug`.
    #
    # @option opts [String, IO] :sso_log The log file where the SSO debug output will be written. The value can be a
    #   string containing a file name or an IO object. If it is a file name then the file will be created if it doesn't
    #   exist, and the SSO debug output will be added to the end. The file will be closed when the connection is closed.
    #   If it is an IO object then the SSO debug output will be written directly, and it won't be closed. Default is
    #   value of `log`.
    #
    # @option opts [Boolean] :sso_timeout The maximun total time to wait for the SSO response, in seconds. A value
    #   of zero means wait for ever. If the timeout expires before the SSO response is received an exception will be
    #   raised. Default is value of `timeout`.
    #
    # @option opts [String] :sso_token_name (access_token) The token name in the JSON SSO response returned from the SSO
    #   server. Default value is `access_token`
    #
  def initialize(opts = {})
      # Get the values of the parameters and assign default values:
      url = opts[:url]
      username = opts[:username]
      password = opts[:password]
      insecure = opts[:insecure] || false
      ca_file = opts[:ca_file]
      debug = opts[:debug] || false
      log = opts[:log]
      kerberos = opts[:kerberos] || false
      timeout = opts[:timeout] || 0
      compress = opts[:compress] || false
      sso_url = opts[:sso_url]
      sso_insecure = opts[:sso_insecure] || insecure
      sso_ca_file = opts[:sso_ca_file] || ca_file
      sso_debug = opts[:sso_debug] || debug
      sso_log = opts[:sso_log] || log
      sso_timeout = opts[:sso_timeout] || timeout
      sso_token_name = opts[:sso_token_name] || 'access_token'

      # Check mandatory parameters:
      if url.nil?
         raise ArgumentError.new("The \"url\" parameter is mandatory.")
      end

      # Save the URL:
      @url = URI(url)

      # Save SSO parameters:
      @sso_url = sso_url
      @username = username
      @password = password
      @kerberos = kerberos
      @sso_insecure = sso_insecure
      @sso_ca_file = sso_ca_file
      @sso_log_file = sso_log
      @sso_debug = sso_debug
      @sso_timeout = sso_timeout
      @log_file = log
      @sso_token_name = sso_token_name;

      # Create the cURL handle:
      @curl = Curl::Easy.new

      # Configure cookies so that they are enabled but stored only in memory:
      @curl.enable_cookies = true
      @curl.cookiefile = '/dev/null'
      @curl.cookiejar = '/dev/null'

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

      # Configure the timeout:
      @curl.timeout = timeout

      # Configure compression of responses (setting the value to a zero length string means accepting all the
      # compression types that libcurl supports):
      if compress
        @curl.encoding = ''
      end

      # Configure debug mode:
      @close_log = false
      if debug
        if log.nil?
          @log = STDOUT
        elsif log.is_a?(String)
          @log = ::File.open(log, 'a')
          @close_log = true
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

      # Check if we already have an SSO access token:
      if @sso_token.nil?
        @sso_token = get_access_token
      end

      # Build the URL:
      @curl.url = build_url({
        :path => request.path,
        :query => request.query,
      })

      # Add headers, avoiding those that have no value:
      @curl.headers.clear
      @curl.headers.merge!(request.headers)
      @curl.headers['User-Agent'] = "RubySDK/#{VERSION}"
      @curl.headers['Version'] = '4'
      @curl.headers['Content-Type'] = 'application/xml'
      @curl.headers['Accept'] = 'application/xml'
      @curl.headers['Authorization'] = 'Bearer ' + @sso_token

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
    # Obtains the access token from SSO to be used for Bearer authentication.
    #
    # @return [String] The URL.
    #
    # @api private
    #
    def get_access_token
      # Create the cURL handle for SSO:
      sso_curl = Curl::Easy.new

      # Configure the timeout:
      sso_curl.timeout = @sso_timeout

      # If SSO url is not supplied build default one:
      if @sso_url.nil?
        @sso_url = build_sso_auth_url
      end

      @sso_url = URI(@sso_url)

      # Configure debug mode:
      sso_close_log = false
      if @sso_debug
        if @sso_log_file.nil?
          sso_log = STDOUT
        elsif @sso_log_file == @log_file
          sso_log = @log
        elsif @sso_log_file.is_a?(String)
          sso_log = ::File.open(@sso_log_file, 'a')
          sso_close_log = true
        else
          sso_log = @sso_log_file
        end
        sso_curl.verbose = true
        sso_curl.on_debug do |type, data|
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
            sso_log.puts(prefix + line)
          end
          sso_log.flush
        end
      end

      begin
        # Configure TLS parameters:
        if @sso_url.scheme == 'https'
          if @sso_insecure
            sso_curl.ssl_verify_peer = false
            sso_curl.ssl_verify_host = false
          elsif @sso_ca_file.nil?
            raise ArgumentError.new("The \"sso_ca_file\" argument is mandatory when using TLS.")
          elsif not ::File.file?(@sso_ca_file)
            raise ArgumentError.new("The CA file \"#{@sso_ca_file}\" doesn't exist.")
          else
            sso_curl.cacert = @sso_ca_file
          end
        end

        # The username and password parameters:
        params = {}

        # The base SSO URL:
        sso_url = @sso_url.to_s

        # Configure authentication:
        if @kerberos
          sso_curl.http_auth_types = :gssnegotiate
          sso_curl.username = ''
          sso_curl.password = ''
        else
          sso_curl.http_auth_types = :basic
          sso_curl.username = @username
          sso_curl.password = @password
          if sso_url.index('?').nil?
            sso_url += '?'
          end
          params['username'] = @username
          params['password'] = @password
          sso_url = sso_url + '&' + URI.encode_www_form(params)
        end

        # Build the SSO access_token request url:
        sso_curl.url = sso_url

        # Add headers:
        sso_curl.headers['User-Agent'] = "RubySDK/#{VERSION}"
        sso_curl.headers['Accept'] = 'application/json'

        # Request access token:
        sso_curl.http_get

        # Parse the JSON response:
        sso_response = JSON.parse(sso_curl.body_str)

        if sso_response.is_a?(Array)
          sso_response = sso_response[0]
        end

        if !sso_response["error"].nil?
          raise Error.new("Error during SSO authentication #{sso_response['error_code']} : #{sso_response['error']}")
        end

        return sso_response[@sso_token_name]
      ensure
        sso_curl.close
        # Close the log file, if we did open it:
        if sso_close_log
          sso_log.close
        end
      end
    end

    ##
    # Builds a request URL to acquire the access token from SSO. The URLS are different for basic auth and Kerberos,
    # @return [String] The URL.
    #
    # @api private
    #
    def build_sso_auth_url
      # Get the base URL:
      @sso_url = @url.to_s[0..@url.to_s.rindex('/')]

      # The SSO access scope:
      scope = 'ovirt-app-api'

      # Set the grant type and entry point to request from SSO:
      if @kerberos
        grant_type = 'urn:ovirt:params:oauth:grant-type:http'
        entry_point = 'token-http-auth'
      else
        grant_type = 'password'
        entry_point = 'token'
      end

      # Build and return the SSO URL:
      return "#{@sso_url}sso/oauth/#{entry_point}?grant_type=#{grant_type}&scope=#{scope}"
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
    # Indicates if the given object is a link. An object is a link if it has an `href` attribute.
    #
    # @return [Boolean]
    #
    def is_link?(object)
      return !object.href.nil?
    end

    ##
    # Follows the `href` attribute of the given object, retrieves the target object and returns it.
    #
    # @param object [Type] The object containing the `href` attribute.
    # @raise [Error] If the `href` attribute has no value, or the link can't be followed.
    #
    def follow_link(object)
      # Check that the "href" has a value, as it is needed in order to retrieve the representation of the object:
      href = object.href
      if href.nil?
        raise Error.new("Can't follow link because the 'href' attribute does't have a value")
      end

      # Check that the value of the "href" attribute is compatible with the base URL of the connection:
      prefix = @url.path
      if !prefix.end_with?('/')
        prefix += '/'
      end
      if !href.start_with?(prefix)
        raise Error.new("The URL '#{href}' isn't compatible with the base URL of the connection")
      end

      # Remove the prefix from the URL, follow the path to the relevant service and invoke the "get" method to
      # retrieve its representation:
      path = href[prefix.length..-1]
      service = service(path)
      return service.get
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
      if @close_log
        @log.close
      end

      # Release resources used by the cURL handle:
      @curl.close
    end

    ##
    # Builds a request URL from a path, and the set of query parameters.
    #
    # @params opts [Hash] The options used to build the URL.
    #
    # @option opts [String] :path The path that will be added to the base URL. The default is an empty string.
    #
    # @option opts [Hash<String, String>] :query ({}) A hash containing the query parameters to add to the URL. The
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

      # Add the path and the parameters:
      url = @url.to_s + path
      if not query.empty?
        url = url + '?' + URI.encode_www_form(query)
      end
      return url
    end

  end

end
