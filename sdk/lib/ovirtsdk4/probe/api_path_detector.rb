module OvirtSDK4
  class Probing::ApiPathDetector
    API_PATH_CANDIDATES = ['/api','/ovirt-engine/api']
    def detect(connection)
      API_PATH_CANDIDATES.each do |path|
        res = connection.send(request(path))
        return path if res.code == 200
        raise "Unauthorized" if res.code == 401
      end
    end

    def request(path)
      Request.new(path: path)
    end
  end
end
