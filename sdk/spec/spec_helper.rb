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

require 'openssl'
require 'socket'
require 'stringio'
require 'tempfile'
require 'uri'
require 'yaml'

require 'ovirtsdk4'

# This is just to shorten the module prefix used in the tests:
SDK = OvirtSDK4

# This module contains utility functions to be used in all the examples.
module Helpers # :nodoc:

  def default_url
    return @parameters['default_url']
  end

  def default_user
    return @parameters['default_user']
  end

  def default_password
    return @parameters['default_password']
  end

  def default_ca_file
    # Check if the CA file is already part of the parameters:
    ca_file = @parameters['default_ca_file']

    if ca_file.nil?
      # Try to get the CA certificate starting the TLS handshake and getting the last certificate of the chain
      # presented by the server:
      parsed_url = URI.parse(default_url)
      begin
        tcp_socket = TCPSocket.open(parsed_url.host, parsed_url.port)
        ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket)
        ssl_socket.connect
        ca_text = ssl_socket.peer_cert_chain.last.to_pem
      ensure
        unless ssl_socket.nil?
          ssl_socket.close
        end
        unless tcp_socket.nil?
          tcp_socket.close
        end
      end

      # Create a temporary file to store the CA certificate:
      ca_fd = Tempfile.new('ca')
      ca_fd.write(ca_text)
      ca_fd.close()
      ca_file = ca_fd.path

      # Update the hash of parameters:
      @parameters['default_ca_file'] = ca_file
    end

    return ca_file
  end

  def default_debug
    return @parameters['default_debug']
  end

  def default_connection
    return SDK::Connection.new({
      :url => default_url,
      :username => default_user,
      :password => default_password,
      :ca_file => default_ca_file,
      :debug => default_debug,
    })
  end

  def load_parameters
    @parameters = File.open('spec/parameters.yaml') do |file|
      YAML::load(file)
    end
  end

end

RSpec.configure do |c|
  # Include the helpers module in all the examples.
  c.include Helpers

  # Load the parameters before running the tests:
  c.before(:all) do
    load_parameters
  end

  # Run the integration test only if the "integration" option is enabled. This means that in order to run the
  # integration tests you will need to use a command like this:
  #
  #   rspec --tag integration
  #
  # These tests can't run by default, because they require a live engine.
  c.filter_run_excluding :integration => true
end
