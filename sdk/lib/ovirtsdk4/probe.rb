#
# Copyright (c) 2016-2017 Red Hat, Inc.
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
  # This class is used to probe the engine to find which API versions it supports.
  #
  class Probe
    #
    # This class method receives a set of options that define the server to probe and returns an arrays of objects of
    # the OvirtSDK4::ProbeResult class containing the results of the probe.
    #
    # @param opts [Hash] The options used to create the probe.
    #
    # @option opts [String] :host The name or IP address of the host to probe.
    #
    # @option opts [Integer] :port (443) The port number to probe.
    #
    # @option opts [String] :username The name of the user, something like `admin@internal`.
    #
    # @option opts [String] :password The password of the user.
    #
    # @option opts [Boolean] :insecure (false) A boolean flag that indicates if the server TLS certificate and host
    #   name should be checked.
    #
    # @option opts [String] :ca_file The name of a PEM file containing the trusted CA certificates. The certificate
    #   presented by the server will be verified using these CA certificates. If not set then the system wide CA
    #   certificates store is used.
    #
    # @option opts [String] :log The logger where the log messages will be written.
    #
    # @option opts [Boolean] :debug (false) A boolean flag indicating if debug output should be generated. If the
    #   values is `true` and the `log` parameter isn't `nil` then the data sent to and received from the server will
    #   be written to the log. Be aware that user names and passwords will also be written, so handle with care.
    #
    # @option opts [String] :proxy_url A string containing the protocol, address and port number of the proxy server
    #   to use to connect to the server. For example, in order to use the HTTP proxy `proxy.example.com` that is
    #   listening on port `3128` the value should be `http://proxy.example.com:3128`. This is optional, and if not
    #   given the connection will go directly to the server specified in the `url` parameter.
    #
    # @option opts [String] :proxy_username The name of the user to authenticate to the proxy server.
    #
    # @option opts [String] :proxy_password The password of the user to authenticate to the proxy server.
    #
    # @return [Array<ProbeResult>] An array of objects of the OvirtSDK4::ProbeResult class.
    #
    def self.probe(opts)
      probe = nil
      begin
        probe = Probe.new(opts)
        probe.probe
      ensure
        probe.close if probe
      end
    end

    ENGINE_CERTIFICATE_PATH =
      '/ovirt-engine/services/pki-resource?resource=engine-certificate&format=OPENSSH-PUBKEY'.freeze

    #
    # This class method receives a set of options that define the server to probe and returns a boolean value
    # that represents whether an oVirt instance was detected.
    #
    # @param opts [Hash] The options used to create the probe.
    #
    # @option opts [String] :host The name or IP address of the host to probe.
    #
    # @option opts [Integer] :port (443) The port number to probe.
    #
    # @option opts [String] :log The logger where the log messages will be written.
    #
    # @option opts [Boolean] :debug (false) A boolean flag indicating if debug output should be generated. If the
    #   values is `true` and the `log` parameter isn't `nil` then the data sent to and received from the server will
    #   be written to the log. Be aware that user names and passwords will also be written, so handle with care.
    #
    # @option opts [String] :proxy_url A string containing the protocol, address and port number of the proxy server
    #   to use to connect to the server. For example, in order to use the HTTP proxy `proxy.example.com` that is
    #   listening on port `3128` the value should be `http://proxy.example.com:3128`. This is optional, and if not
    #   given the connection will go directly to the server specified in the `url` parameter.
    #
    # @option opts [Integer] :timeout (0) Set a connection timeout, in seconds. If the value is 0 no timeout is set.
    #
    # @return [Boolean] Boolean value, `true` if an oVirt instance was detected.
    #
    def self.exists?(opts)
      probe = nil
      begin
        opts[:insecure] = true
        probe = Probe.new(opts)
        probe.exists?
      ensure
        probe.close if probe
      end
    end

    #
    # Creates a new probe.
    #
    # @param opts [Hash] The options used to create the probe.
    #
    # @option opts [String] :host The name or IP address of the host to probe.
    #
    # @option opts [Integer] :port (443) The port number to probe.
    #
    # @option opts [String] :username The name of the user, something like `admin@internal`.
    #
    # @option opts [String] :password The password of the user.
    #
    # @option opts [Boolean] :insecure (false) A boolean flag that indicates if the server TLS certificate and host
    #   name should be checked.
    #
    # @option opts [String] :ca_file The name of a PEM file containing the trusted CA certificates. The certificate
    #   presented by the server will be verified using these CA certificates. If not set then the system wide CA
    #   certificates store is used.
    #
    # @option opts [String] :log The logger where the log messages will be written.
    #
    # @option opts [Boolean] :debug (false) A boolean flag indicating if debug output should be generated. If the
    #   values is `true` and the `log` parameter isn't `nil` then the data sent to and received from the server will
    #   be written to the log. Be aware that user names and passwords will also be written, so handle with care.
    #
    # @option opts [String] :proxy_url A string containing the protocol, address and port number of the proxy server
    #   to use to connect to the server. For example, in order to use the HTTP proxy `proxy.example.com` that is
    #   listening on port `3128` the value should be `http://proxy.example.com:3128`. This is optional, and if not
    #   given the connection will go directly to the server specified in the `url` parameter.
    #
    # @option opts [String] :proxy_username The name of the user to authenticate to the proxy server.
    #
    # @option opts [String] :proxy_password The password of the user to authenticate to the proxy server.
    #
    # @api private
    #
    def initialize(opts)
      # Get the options and assign default values:
      @host           = opts[:host]
      @port           = opts[:port] || 443
      @username       = opts[:username]
      @password       = opts[:password]
      @insecure       = opts[:insecure] || false
      @ca_file        = opts[:ca_file]
      @log            = opts[:log]
      @debug          = opts[:debug] || false
      @proxy_url      = opts[:proxy_url]
      @proxy_username = opts[:proxy_username]
      @proxy_password = opts[:proxy_password]
      @timeout        = opts[:timeout]

      # Create the HTTP client:
      @client = HttpClient.new(
        host:           @host,
        port:           @port,
        insecure:       @insecure,
        ca_file:        @ca_file,
        log:            @log,
        debug:          @debug,
        proxy_url:      @proxy_url,
        proxy_username: @proxy_username,
        proxy_password: @proxy_password,
        timeout:        @timeout
      )
    end

    #
    # Probes the server to detect the supported versions of the API.
    #
    # @return [Array<ProbeResult>] An array of objects of the OvirtSDK4::ProbeResult class.
    #
    # @api private
    #
    def probe
      path = detect_path
      raise Error, 'API path not found' unless path

      detect_version(path).map { |version| ProbeResult.new(version: version) }
    end

    #
    # Probes the server to detect if it has an ovirt instance running on it
    #
    # @return [Boolean] `true` if oVirt instance was detected, false otherwise
    #
    # @api private
    #
    def exists?
      response = send(path: ENGINE_CERTIFICATE_PATH)
      response.code == 200
    end

    #
    # Releases the resources used by this probe.
    #
    # @api private
    #
    def close
      # Close the HTTP client:
      @client.close if @client
    end

    private

    #
    # We will only check these paths, as there is where the API is available in common installations of the engine.
    #
    PATH_CANDIDATES = [
      '/api',
      '/ovirt-engine/api'
    ].freeze

    def send(opts = {})
      # Get the options and assign default values:
      path = opts[:path] || ''
      version = opts[:version] || '4'

      # Create the request:
      request = HttpRequest.new
      request.url = "https://#{@host}:#{@port}#{path}"

      # Set the headers:
      request.headers.merge!(
        'User-Agent'   => "RubyProbe/#{VERSION}",
        'Version'      => version,
        'Content-Type' => 'application/xml',
        'Accept'       => 'application/xml'
      )

      # Set authentication:
      request.username = @username

      request.password = @password
      # Send the request and wait for the response:
      @client.send(request)
      response = @client.wait(request)
      raise response if response.is_a?(Exception)

      response
    end

    def detect_path
      PATH_CANDIDATES.each do |path|
        response = send(path: path)
        return path if response.code == 200
        raise AuthError, 'Unauthorized' if response.code == 401
      end
      nil
    end

    def detect_version(path)
      versions = []
      versions << '3' if detect_v3(path)
      versions << '4' if detect_v4(path)
      versions
    end

    def detect_v3(path)
      response = send(version: '3', path: path)
      special_response_regexp_in_api3 =~ response.body
    end

    def detect_v4(path)
      response = send(version: '4', path: path)
      special_response_regexp_in_api4 =~ response.body
    end

    # The methods below are based on headers oVirt returns depending on the API
    # version it supports when queried with <version: 3> or <version: 4> header.
    # Refer to spec to see the return values.
    def special_response_regexp_in_api3
      /major=/
    end

    def special_response_regexp_in_api4
      /<major>/
    end
  end

  #
  # The probe returns an array of instances of this class.
  #
  class ProbeResult
    attr_reader :version

    #
    # This method is used to initialize a class instance,
    #
    # @param opts [Hash] The attributes of the result.
    #
    # @option opts [String] :version The version obtained as the result of the probe.
    #
    def initialize(opts)
      @version = opts[:version]
    end

    # Override the comparison method.
    def ==(other)
      other.class == self.class && other.state == state
    end

    alias eql? ==

    # Should always be overriden if one overrides ==, used to get a hash value
    # for the object.
    def hash
      state.hash
    end

    # @api private
    def state
      [version]
    end
  end
end
