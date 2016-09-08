module OvirtSDK4
  module Probing
    class Probe
      attr_reader :api_path_detector, :api_version_detector
      attr_accessor :connection

      def self.probe(connection_args)
        self.new(api_path_detector: ApiPathDetector.new, api_version_detector: ApiVersionDetector.new)
          .probe(connection_args)
      end

      def initialize(args)
        @api_path_detector = args[:api_path_detector]
        @api_version_detector = args[:api_version_detector]
      end

      def probe(connection_args)
        connection = OvirtSDK4::Connection.new(connection_args)
        path = api_path_detector.detect(connection)
        api_version_detector.detect(connection, path)
      ensure
        connection.close
      end
    end
  end
end
