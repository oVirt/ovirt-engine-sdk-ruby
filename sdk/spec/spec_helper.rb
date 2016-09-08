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

require 'json'
require 'logger'
require 'openssl'
require 'socket'
require 'uri'
require 'webrick'
require 'webrick/https'

require 'ovirtsdk4'

# This is just to shorten the module prefix used in the tests:
SDK = OvirtSDK4

# This module contains utility functions to be used in all the examples.
module Helpers # :nodoc:

  attr_reader :last_request_query, :last_request_method, :last_request_body

  # The authentication details used by the embedded tests web server:
  REALM = 'API'
  USER = 'admin@internal'
  PASSWORD = 'vzhJgfyaDPHRhg'
  TOKEN = 'bvY7txV9ltmmRQ'

  # The host and port and path used by the embedded tests web server:
  HOST = 'localhost'
  PREFIX = '/ovirt-engine'

  # Content types:
  APPLICATION_FORM = 'application/x-www-form-urlencoded'
  APPLICATION_JSON = 'application/json'
  APPLICATION_XML = 'application/xml'

  def test_user
    return USER
  end

  def test_password
    return PASSWORD
  end

  def test_token
    TOKEN
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

  def test_debug
    true
  end

  def test_log
    @log ||= Logger.new('spec/client.log')
  end

  def test_connection
    return SDK::Connection.new(
      :url => test_url,
      :username => test_user,
      :password => test_password,
      :ca_file => test_ca_file,
      :debug => test_debug,
      :log => test_log,
    )
  end

  def check_sso_request(request, response)
    # Check the HTTP method:
    expected_method = 'POST'
    actual_method = request.request_method
    unless actual_method == expected_method
      response.status = 401
      response.content_type = APPLICATION_JSON
      response.body = JSON.generate(
        :error_code => 0,
        :error => "The HTTP method should be '#{expected_method}', but it is '#{actual_method}'"
      )
      return false
    end

    # Check the content type:
    expected_content_type = APPLICATION_FORM
    actual_content_type = request.content_type
    unless actual_content_type == expected_content_type
      response.status = 401
      response.content_type = APPLICATION_JSON
      response.body = JSON.generate(
        :error_code => 0,
        :error => "The 'Content-Type' header should be '#{expected_content_type}', but it is '#{actual_content_type}'"
      )
      return false
    end

    # Check that there is no query string, all the parameters should be part of the body:
    expected_query = ''
    actual_query = request.meta_vars['QUERY_STRING']
    unless actual_query == expected_query
      response.status = 401
      response.content_type = APPLICATION_JSON
      response.body = JSON.generate(
        :error_code => 0,
        :error => "The query string should be '#{expected_query}', but it is '#{actual_query}'"
      )
      return false
    end

    # Everything seems correct:
    true
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
      # Check basic properties of the request:
      next unless check_sso_request(request, response)

      # Check that the password is correct:
      expected_password = test_password
      actual_password = request.query['password']
      unless actual_password == expected_password
        response.status = 401
        response.content_type = APPLICATION_JSON
        response.body = JSON.generate(
          :error_code => 0,
          :error => "The password should be '#{expected_password}', but it is '#{actual_password}'"
        )
        next
      end

      # Everything seems correct:
      response.status = 200
      response.content_type = APPLICATION_JSON
      response.body = JSON.generate(
        :access_token => test_token,
      )
    end

    # Create handeler for basic_auth requests:

    # Create the handler for Kerberos authentication requests:
    @server.mount_proc "#{PREFIX}/sso/oauth/token-http-auth" do |request, response|
      # Check basic properties of the request:
      next unless check_sso_request(request, response)

      # Everything seems correct:
      response.status = 200
      response.content_type = APPLICATION_JSON
      response.body = JSON.generate(
        :access_token => test_token,
      )
    end

    # Create the handler for SSO logout requests:
    @server.mount_proc "#{PREFIX}/services/sso-logout" do |request, response|
      # Check basic properties of the request:
      next unless check_sso_request(request, response)

      # Check that the token is correct:
      expected_token = test_token
      actual_token = request.query['token']
      unless actual_token == expected_token
        response.status = 401
        response.content_type = APPLICATION_JSON
        response.body = JSON.generate(
          :error_code => 0,
          :error => "The token should be '#{expected_token}', but it is '#{actual_token}'"
        )
        next
      end

      # Everything seems correct:
      response.status = 200
      response.content_type = APPLICATION_JSON
      response.body = JSON.generate({})
    end

    @server.mount_proc "#{PREFIX}/apis" do |request, response|
      @authenticator.authenticate(request, response)
    end


    # Start the server in a different thread, as the call to the "start" method blocks the current thread:
    @thread = Thread.new {
      @server.start
    }
  end

  API_V3_RESPONSE = '<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<api>\n    <link href=\"/ovirt-engine/api/capabilities\" rel=\"capabilities\"/>\n    <link href=\"/ovirt-engine/api/clusters\" rel=\"clusters\"/>\n    <link href=\"/ovirt-engine/api/clusters?search={query}\" rel=\"clusters/search\"/>\n    <link href=\"/ovirt-engine/api/datacenters\" rel=\"datacenters\"/>\n    <link href=\"/ovirt-engine/api/datacenters?search={query}\" rel=\"datacenters/search\"/>\n    <link href=\"/ovirt-engine/api/events\" rel=\"events\"/>\n    <link href=\"/ovirt-engine/api/events;from={event_id}?search={query}\" rel=\"events/search\"/>\n    <link href=\"/ovirt-engine/api/hosts\" rel=\"hosts\"/>\n    <link href=\"/ovirt-engine/api/hosts?search={query}\" rel=\"hosts/search\"/>\n    <link href=\"/ovirt-engine/api/networks\" rel=\"networks\"/>\n    <link href=\"/ovirt-engine/api/networks?search={query}\" rel=\"networks/search\"/>\n    <link href=\"/ovirt-engine/api/roles\" rel=\"roles\"/>\n    <link href=\"/ovirt-engine/api/storagedomains\" rel=\"storagedomains\"/>\n    <link href=\"/ovirt-engine/api/storagedomains?search={query}\" rel=\"storagedomains/search\"/>\n    <link href=\"/ovirt-engine/api/tags\" rel=\"tags\"/>\n    <link href=\"/ovirt-engine/api/bookmarks\" rel=\"bookmarks\"/>\n    <link href=\"/ovirt-engine/api/icons\" rel=\"icons\"/>\n    <link href=\"/ovirt-engine/api/templates\" rel=\"templates\"/>\n    <link href=\"/ovirt-engine/api/templates?search={query}\" rel=\"templates/search\"/>\n    <link href=\"/ovirt-engine/api/instancetypes\" rel=\"instancetypes\"/>\n    <link href=\"/ovirt-engine/api/instancetypes?search={query}\" rel=\"instancetypes/search\"/>\n    <link href=\"/ovirt-engine/api/users\" rel=\"users\"/>\n    <link href=\"/ovirt-engine/api/users?search={query}\" rel=\"users/search\"/>\n    <link href=\"/ovirt-engine/api/groups\" rel=\"groups\"/>\n    <link href=\"/ovirt-engine/api/groups?search={query}\" rel=\"groups/search\"/>\n    <link href=\"/ovirt-engine/api/domains\" rel=\"domains\"/>\n    <link href=\"/ovirt-engine/api/vmpools\" rel=\"vmpools\"/>\n    <link href=\"/ovirt-engine/api/vmpools?search={query}\" rel=\"vmpools/search\"/>\n    <link href=\"/ovirt-engine/api/vms\" rel=\"vms\"/>\n    <link href=\"/ovirt-engine/api/vms?search={query}\" rel=\"vms/search\"/>\n    <link href=\"/ovirt-engine/api/disks\" rel=\"disks\"/>\n    <link href=\"/ovirt-engine/api/disks?search={query}\" rel=\"disks/search\"/>\n    <link href=\"/ovirt-engine/api/jobs\" rel=\"jobs\"/>\n    <link href=\"/ovirt-engine/api/storageconnections\" rel=\"storageconnections\"/>\n    <link href=\"/ovirt-engine/api/vnicprofiles\" rel=\"vnicprofiles\"/>\n    <link href=\"/ovirt-engine/api/diskprofiles\" rel=\"diskprofiles\"/>\n    <link href=\"/ovirt-engine/api/cpuprofiles\" rel=\"cpuprofiles\"/>\n    <link href=\"/ovirt-engine/api/schedulingpolicyunits\" rel=\"schedulingpolicyunits\"/>\n    <link href=\"/ovirt-engine/api/schedulingpolicies\" rel=\"schedulingpolicies\"/>\n    <link href=\"/ovirt-engine/api/permissions\" rel=\"permissions\"/>\n    <link href=\"/ovirt-engine/api/macpools\" rel=\"macpools\"/>\n    <link href=\"/ovirt-engine/api/networkfilters\" rel=\"networkfilters\"/>\n    <link href=\"/ovirt-engine/api/operatingsystems\" rel=\"operatingsystems\"/>\n    <link href=\"/ovirt-engine/api/externalhostproviders\" rel=\"externalhostproviders\"/>\n    <link href=\"/ovirt-engine/api/openstackimageproviders\" rel=\"openstackimageproviders\"/>\n    <link href=\"/ovirt-engine/api/openstackvolumeproviders\" rel=\"openstackvolumeproviders\"/>\n    <link href=\"/ovirt-engine/api/openstacknetworkproviders\" rel=\"openstacknetworkproviders\"/>\n    <link href=\"/ovirt-engine/api/katelloerrata\" rel=\"katelloerrata\"/>\n    <special_objects>\n        <link href=\"/ovirt-engine/api/templates/00000000-0000-0000-0000-000000000000\" rel=\"templates/blank\"/>\n        <link href=\"/ovirt-engine/api/tags/00000000-0000-0000-0000-000000000000\" rel=\"tags/root\"/>\n    </special_objects>\n    <product_info>\n        <name>oVirt Engine</name>\n        <vendor>ovirt.org</vendor>\n        <version major=\"4\" minor=\"1\" build=\"0\" revision=\"0\"/>\n        <full_version>4.1.0_master</full_version>\n    </product_info>\n    <summary>\n        <vms>\n            <total>8</total>\n            <active>0</active>\n        </vms>\n        <hosts>\n            <total>3</total>\n            <active>1</active>\n        </hosts>\n        <users>\n            <total>1</total>\n            <active>1</active>\n        </users>\n        <storage_domains>\n            <total>5</total>\n            <active>3</active>\n        </storage_domains>\n    </summary>\n    <time>2016-09-13T14:06:11.184+03:00</time>\n</api>\n'
  API_V4_RESPONSE = '<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<api>\n    <link href=\"/ovirt-engine/api/clusters\" rel=\"clusters\"/>\n    <link href=\"/ovirt-engine/api/clusters?search={query}\" rel=\"clusters/search\"/>\n    <link href=\"/ovirt-engine/api/datacenters\" rel=\"datacenters\"/>\n    <link href=\"/ovirt-engine/api/datacenters?search={query}\" rel=\"datacenters/search\"/>\n    <link href=\"/ovirt-engine/api/events\" rel=\"events\"/>\n    <link href=\"/ovirt-engine/api/events;from={event_id}?search={query}\" rel=\"events/search\"/>\n    <link href=\"/ovirt-engine/api/hosts\" rel=\"hosts\"/>\n    <link href=\"/ovirt-engine/api/hosts?search={query}\" rel=\"hosts/search\"/>\n    <link href=\"/ovirt-engine/api/networks\" rel=\"networks\"/>\n    <link href=\"/ovirt-engine/api/networks?search={query}\" rel=\"networks/search\"/>\n    <link href=\"/ovirt-engine/api/roles\" rel=\"roles\"/>\n    <link href=\"/ovirt-engine/api/storagedomains\" rel=\"storagedomains\"/>\n    <link href=\"/ovirt-engine/api/storagedomains?search={query}\" rel=\"storagedomains/search\"/>\n    <link href=\"/ovirt-engine/api/tags\" rel=\"tags\"/>\n    <link href=\"/ovirt-engine/api/bookmarks\" rel=\"bookmarks\"/>\n    <link href=\"/ovirt-engine/api/icons\" rel=\"icons\"/>\n    <link href=\"/ovirt-engine/api/templates\" rel=\"templates\"/>\n    <link href=\"/ovirt-engine/api/templates?search={query}\" rel=\"templates/search\"/>\n    <link href=\"/ovirt-engine/api/instancetypes\" rel=\"instancetypes\"/>\n    <link href=\"/ovirt-engine/api/instancetypes?search={query}\" rel=\"instancetypes/search\"/>\n    <link href=\"/ovirt-engine/api/users\" rel=\"users\"/>\n    <link href=\"/ovirt-engine/api/users?search={query}\" rel=\"users/search\"/>\n    <link href=\"/ovirt-engine/api/groups\" rel=\"groups\"/>\n    <link href=\"/ovirt-engine/api/groups?search={query}\" rel=\"groups/search\"/>\n    <link href=\"/ovirt-engine/api/domains\" rel=\"domains\"/>\n    <link href=\"/ovirt-engine/api/vmpools\" rel=\"vmpools\"/>\n    <link href=\"/ovirt-engine/api/vmpools?search={query}\" rel=\"vmpools/search\"/>\n    <link href=\"/ovirt-engine/api/vms\" rel=\"vms\"/>\n    <link href=\"/ovirt-engine/api/vms?search={query}\" rel=\"vms/search\"/>\n    <link href=\"/ovirt-engine/api/disks\" rel=\"disks\"/>\n    <link href=\"/ovirt-engine/api/disks?search={query}\" rel=\"disks/search\"/>\n    <link href=\"/ovirt-engine/api/jobs\" rel=\"jobs\"/>\n    <link href=\"/ovirt-engine/api/storageconnections\" rel=\"storageconnections\"/>\n    <link href=\"/ovirt-engine/api/vnicprofiles\" rel=\"vnicprofiles\"/>\n    <link href=\"/ovirt-engine/api/diskprofiles\" rel=\"diskprofiles\"/>\n    <link href=\"/ovirt-engine/api/cpuprofiles\" rel=\"cpuprofiles\"/>\n    <link href=\"/ovirt-engine/api/schedulingpolicyunits\" rel=\"schedulingpolicyunits\"/>\n    <link href=\"/ovirt-engine/api/schedulingpolicies\" rel=\"schedulingpolicies\"/>\n    <link href=\"/ovirt-engine/api/permissions\" rel=\"permissions\"/>\n    <link href=\"/ovirt-engine/api/macpools\" rel=\"macpools\"/>\n    <link href=\"/ovirt-engine/api/networkfilters\" rel=\"networkfilters\"/>\n    <link href=\"/ovirt-engine/api/operatingsystems\" rel=\"operatingsystems\"/>\n    <link href=\"/ovirt-engine/api/externalhostproviders\" rel=\"externalhostproviders\"/>\n    <link href=\"/ovirt-engine/api/openstackimageproviders\" rel=\"openstackimageproviders\"/>\n    <link href=\"/ovirt-engine/api/openstackvolumeproviders\" rel=\"openstackvolumeproviders\"/>\n    <link href=\"/ovirt-engine/api/openstacknetworkproviders\" rel=\"openstacknetworkproviders\"/>\n    <link href=\"/ovirt-engine/api/katelloerrata\" rel=\"katelloerrata\"/>\n    <link href=\"/ovirt-engine/api/affinitylabels\" rel=\"affinitylabels\"/>\n    <link href=\"/ovirt-engine/api/clusterlevels\" rel=\"clusterlevels\"/>\n    <product_info>\n        <name>oVirt Engine</name>\n        <vendor>ovirt.org</vendor>\n        <version>\n            <build>0</build>\n            <full_version>4.1.0_master</full_version>\n            <major>4</major>\n            <minor>1</minor>\n            <revision>0</revision>\n        </version>\n    </product_info>\n    <special_objects>\n        <blank_template href=\"/ovirt-engine/api/templates/00000000-0000-0000-0000-000000000000\" id=\"00000000-0000-0000-0000-000000000000\"/>\n        <root_tag href=\"/ovirt-engine/api/tags/00000000-0000-0000-0000-000000000000\" id=\"00000000-0000-0000-0000-000000000000\"/>\n    </special_objects>\n    <summary>\n        <hosts>\n            <active>1</active>\n            <total>3</total>\n        </hosts>\n        <storage_domains>\n            <active>3</active>\n            <total>5</total>\n        </storage_domains>\n        <users>\n            <active>1</active>\n            <total>1</total>\n        </users>\n        <vms>\n            <active>0</active>\n            <total>8</total>\n        </vms>\n    </summary>\n    <time>2016-09-11T12:54:21.551+03:00</time>\n</api>\n'

  def set_support_only_api_v3
    set_xml_response('', 200, API_V3_RESPONSE)
  end

  def set_support_only_api_v4
    set_xml_response('', 200, API_V4_RESPONSE)
  end

  def conditional_api_response_lambda
    -> (req) do
      case req["version"]
      when "3"
        return API_V3_RESPONSE
      when "4"
        return API_V4_RESPONSE
      end
    end
  end

  def set_support_for_api_v3_and_v4
    set_xml_response('', 200,'',0, conditional_api_response_lambda)
  end

  def set_xml_response(path, status, body, delay = 0, conditional_body_lambda = nil)
    @server.mount_proc "#{PREFIX}/api/#{path}" do |request, response|
      # Save the request details:
      @last_request_method = request.request_method
      @last_request_body = request.body
      # The query string can't be obtained directly from the request object, only a hash with the query
      # parameter, and that is only available for GET and HEAD requests. We need it for POST and PUT
      # requests, so we need to get them using the CGI variables.
      vars = request.meta_vars
      @last_request_query = vars['QUERY_STRING']
      body = conditional_body_lambda.call(request) if conditional_body_lambda
      # Check credentials, and if they are correct return the response:
      authorization = request['Authorization']
      if authorization != "Bearer #{test_token}"
        response.status = 401
        response.body = ''
      else
        sleep(delay)
        response.content_type = APPLICATION_XML
        response.body = body
        response.status = status
      end
    end
  end

  def stop_server
    @server.shutdown
    @thread.join
  end

end

RSpec.configure do |c|
  # Include the helpers module in all the examples.
  c.include Helpers
end
