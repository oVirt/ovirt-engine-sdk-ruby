#
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
#

module OvirtSDK4
  #
  # This class is used to probe the engine to find which API versions
  # it supports.
  #
  class Probe
    attr_reader :path_detector,
                :version_detector

    #
    # This class method receives an OvirtSDK4::Connection and returns the API
    # versions that the server supports.
    #
    def self.probe(connection)
      new(path_detector: PathDetector.new,
          version_detector: VersionDetector.new)
        .probe(connection)
    end

    #
    # @param args [Hash] the arguments for the initalization for the
    #   probe class.
    # @options args connection - an instance of OvirtSDK4::Connection
    # @options args [PathDetector] - an instance of a class that can
    #   recevie a connection and return the servers API path.
    # @options args version_detector - an instance of a class that
    #   can receive a connection and an API path and return the API
    #   versions the server supports.
    # @api private
    def initialize(args)
      @path_detector = args[:path_detector]
      @version_detector = args[:version_detector]
    end

    #
    # This instance method probes the connection to find the
    # API version that the server supports.
    # @return array of supported version strings.
    # @param connection [OvirtSDK4::Connection]
    # @api private
    #
    def probe(connection)
      path = path_detector.detect(connection)
      raise OvirtSDK4::Error.new('API path not found') unless path
      version_detector.detect(connection, path)
    end
  end

  # This class is responsible for detecting the API path an oVirt server.
  # @api private
  class PathDetector
    API_PATH_CANDIDATES = [
      '/api',
      '/ovirt-engine/api'
    ].freeze

    def detect(connection)
      API_PATH_CANDIDATES.each do |path|
        res = connection.send(request(path))
        return path if res.code == 200
        raise OvirtSDK4::Error.new('Unauthorized') if res.code == 401
      end
      nil
    end

    def request(path)
      Request.new(path: path)
    end
  end

  # This class is responsible for detecting the API versions an oVirt server.
  # engine supports.
  # @api private
  class VersionDetector
    attr_accessor :supported_versions,
                  :path,
                  :connection
    def detect(connection, path)
      self.connection = connection
      self.path = path
      supported_versions = []
      supported_versions << '3' if detect_v3
      supported_versions << '4' if detect_v4
      supported_versions
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
      OvirtSDK4::Request.new(path: path,
                             headers: { version: 3 })
    end

    def request_for_v4_detection
      OvirtSDK4::Request.new(path: path,
                             headers: { version: 4 })
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
end
