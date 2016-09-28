#
# Copyright (c) 2016 Red Hat, Inc.
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
    attr_reader :path_detector,
                :version_detector

    #
    # This class method receives a set of options that define the server to probe and returns an arrays of objects of
    # the OvirtSDK4::ProbeResult class containing the results of the probe.
    #
    # @options opts [Hash] The options used to create the probe.
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
    # @option opts [Boolean] :debug (false)  (false) A boolean flag indicating if debug output should be generated. If
    #   the values is `true` and the `log` parameter isn't `nil` then the data sent to and received from the server
    #   will be written to the log. Be aware that user names and passwords will also be written, so handle with care.
    #
    def self.probe(opts)
      new(path_detector: PathDetector.new,
          version_detector: VersionDetector.new)
        .probe(opts)
    end

    #
    # Creates a new probe instance.
    #
    # @param opts [Hash] The options for the initalization for the probe instance.
    #
    # @option opts [PathDetector] :path_detector An instance of a class that can recevie a connection and return the
    #   servers API path.
    #
    # @options opts [VersionDetector] :version_detector An instance of a class that can receive a connection and an
    #   API path and return the API versions the server supports.
    #
    # @api private
    #
    def initialize(opts)
      @path_detector = opts[:path_detector]
      @version_detector = opts[:version_detector]
    end

    #
    # This instance method receives a set of options that define the server to probe and returns the API versions that
    # the server supports.
    #
    # @param opts [Hash] The options to base the probing on. See the `probe` class method for details.
    #
    # @api private
    #
    def probe(opts)
      path = path_detector.detect(opts)
      raise OvirtSDK4::Error.new('API path not found') unless path
      version_detector.detect(opts, path).map { |version| ProbeResult.new(version: version) }
    end
  end

  #
  # This class is responsible for detecting the API path an oVirt server.
  #
  # @api private
  #
  class PathDetector
    PATH_CANDIDATES = [
      '/api',
      '/ovirt-engine/api'
    ].freeze

    def detect(opts)
      PATH_CANDIDATES.each do |path|
        begin
          connection = ConnectionBuilder.build(opts.merge(path: path))
          res = connection.send(request)
          return path if res.code == 200
          raise OvirtSDK4::Error.new('Unauthorized') if res.code == 401
        ensure
          connection.close if connection
        end
      end
      nil
    end

    def request
      Request.new(path: '')
    end
  end

  #
  # Class contains class methods to build connections from options.
  #
  # @api private
  #
  class ConnectionBuilder
    DEFAULT_PORT = 443

    def self.build(opts)
      Connection.new(
        url:      build_url(opts),
        username: opts[:username],
        password: opts[:password],
        insecure: opts[:insecure],
        ca_file:  opts[:ca_file],
        log:      opts[:log],
        debug:    opts[:debug],
        auth:     :basic
      )
    end

    def self.build_url(opts)
      host = opts[:host]
      path = opts[:path]
      port = opts[:port] || DEFAULT_PORT
      "https://#{host}:#{port}#{path}"
    end
  end

  #
  # This class is responsible for detecting the API versions an oVirt server engine supports.
  #
  # @api private
  #
  class VersionDetector
    attr_accessor :supported_versions,
                  :path,
                  :connection

    def detect(connection_opts, path)
      @connection = ConnectionBuilder.build(connection_opts.merge(path: path))
      self.path = path
      supported_versions = []
      supported_versions << '3' if detect_v3
      supported_versions << '4' if detect_v4
      supported_versions
    ensure
      @connection.close if @connection
    end

    private

    def detect_v3
      res = connection.send(request_for_v3_detection)
      special_response_regexp_in_api3 =~ res.body
    end

    def detect_v4
      res = connection.send(request_for_v4_detection)
      special_response_regexp_in_api4 =~ res.body
    end

    def request_for_v3_detection
      OvirtSDK4::Request.new(
        path: '',
        headers: { version: 3 },
      )
    end

    def request_for_v4_detection
      OvirtSDK4::Request.new(
        path: '',
        headers: { version: 4 },
      )
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
    def ==(o)
      o.class == self.class && o.state == state
    end

    alias_method :eql?, :==

    # Should always be overriden if one overrides ==, used to get a hash value
    # for the object.
    def hash
      state.hash
    end

    #@api private
    def state
      [version]
    end
  end
end
