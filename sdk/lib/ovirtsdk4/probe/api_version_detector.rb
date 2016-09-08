module OvirtSDK4
  class Probing::ApiVersionDetector

    attr_accessor :supported_versions, :path, :connection
    def detect(connection, path)
      self.connection = connection
      supported_versions = []
      if detect_v3
        supported_versions << "3"
      end
      if detect_v4
        supported_versions << "4"
      end
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
                             headers: {:version => 3})
    end

    def request_for_v4_detection
      OvirtSDK4::Request.new(path: path,
                             headers: {:version => 4})
    end

    def special_response_regexp_in_api3
      /version major/
    end

    def special_response_regexp_in_api4
      /<major>/
    end
  end
end
