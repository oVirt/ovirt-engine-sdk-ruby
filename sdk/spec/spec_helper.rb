#
# Copyright (c) 2015 Red Hat, Inc.
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

require 'json'
require 'openssl'
require 'socket'
require 'tempfile'
require 'uri'
require 'webrick'
require 'webrick/https'

require 'ovirtsdk4'

# This is just to shorten the module prefix used in the tests:
SDK = OvirtSDK4

# This module contains utility functions to be used in all the examples.
module Helpers # :nodoc:

  # The authentication details used by the embedded tests web server:
  REALM = 'API'
  USER = 'admin@internal'
  PASSWORD = 'vzhJgfyaDPHRhg'
  TOKEN = 'bvY7txV9ltmmRQ'

  # The host and port and path used by the embedded tests web server:
  HOST = 'localhost'
  PREFIX = '/ovirt-engine'

  def test_user
    return USER
  end

  def test_password
    return PASSWORD
  end

  def test_host
    return HOST
  end

  def test_port
    if @port.nil?
      range = 60000..61000
      port = range.first
      begin
        server = TCPServer.new(test_host, port)
      rescue Errno::EADDRINUSE
        port += 1
        retry if port <= range.last
        raise "Can't find a free port in range #{range}"
      ensure
        server.close unless server.nil?
      end
      @port = port
    end
    return @port
  end

  def test_prefix
    return PREFIX
  end

  def test_url
    return "https://#{test_host}:#{test_port}#{test_prefix}/api"
  end

  def test_ca_file
    return 'spec/pki/ca.crt'
  end

  def test_connection
    return SDK::Connection.new(
      :url => test_url,
      :username => test_user,
      :password => test_password,
      :ca_file => test_ca_file,
    )
  end

  def start_server(host = 'localhost')
    # Load the private key and the certificate corresponding to the given host name:
    key = OpenSSL::PKey::RSA.new(File.read("spec/pki/#{host}.key"))
    crt = OpenSSL::X509::Certificate.new(File.read("spec/pki/#{host}.crt"))

    # Prepare the authentication configuration:
    db_file = Tempfile.new('users')
    db_path = db_file.path
    db_file.close
    db_file.unlink
    db = WEBrick::HTTPAuth::Htpasswd.new(db_path)
    db.auth_type = WEBrick::HTTPAuth::BasicAuth
    db.set_passwd(REALM, USER, PASSWORD)
    db.flush
    @authenticator = WEBrick::HTTPAuth::BasicAuth.new(
      :Realm => REALM,
      :UserDB => db,
    )

    # Prepare a loggers that write to files, so that the log output isn't mixed with the tests output:
    server_log = WEBrick::Log.new('spec/server.log', WEBrick::Log::DEBUG)
    access_log = File.open('spec/access.log', 'w')

    # Create the web server:
    @server = WEBrick::HTTPServer.new(
      :BindAddress => test_host,
      :Port => test_port,
      :SSLEnable => true,
      :SSLPrivateKey => key,
      :SSLCertificate => crt,
      :Logger => server_log,
      :AccessLog => [[access_log, WEBrick::AccessLog::COMBINED_LOG_FORMAT]],
    )

    # Create the handler for password authentication requests:
    @server.mount_proc "#{PREFIX}/sso/oauth/token" do |request, response|
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = JSON.generate(
        :access_token => TOKEN,
      )
    end

    # Create the handler for SSO logout requests:
    @server.mount_proc "#{PREFIX}/services/sso-logout" do |request, response|
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = JSON.generate(
          :access_token => TOKEN,
      )
    end

    # Create the handler for Kerberos authentication requests:
    @server.mount_proc "#{PREFIX}/sso/oauth/token-http-auth" do |request, response|
      response.status = 200
      response['Content-Type'] = 'application/json'
      response.body = JSON.generate(
        :access_token => TOKEN,
      )
    end

    # Start the server in a different thread, as the call to the "start" method blocks the current thread:
    @thread = Thread.new {
      @server.start
    }
  end

  def set_xml_response(path, status, body, delay = 0)
    @server.mount_proc "#{PREFIX}/api/#{path}" do |request, response|
      # Save the request details:
      @last_request_method = request.request_method
      @last_request_body = request.body

      # Check credentials, and if they are correct return the response:
      authorization = request['Authorization']
      if authorization != "Bearer #{TOKEN}"
        response.status = 401
        response.body = ''
      else
        sleep(delay)
        response['Content-Type'] = 'application/xml'
        response.body = body
        response.status = status
      end
    end
  end

  def stop_server
    @server.shutdown
    @thread.join
  end

  def last_request_method
    return @last_request_method
  end

  def last_request_body
    return @last_request_body
  end

end

RSpec.configure do |c|
  # Include the helpers module in all the examples.
  c.include Helpers
end
