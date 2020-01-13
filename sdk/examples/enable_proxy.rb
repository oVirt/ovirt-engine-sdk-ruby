#!/usr/bin/ruby

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

require 'logger'
require 'ovirtsdk4'

# This example shows how to use the SDK when there is the need to use an
# HTTP proxy to connect to the server:

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:            'https://engine41.example.com/ovirt-engine/api',
  username:       'admin@internal',
  password:       'redhat123',
  ca_file:        'ca.pem',
  proxy_url:      'http://proxy.example.com:3128',
  proxy_username: 'myproxyuser',
  proxy_password: 'myproxypass',
  debug:          true,
  log:            Logger.new('example.log')
)

# Get the reference to the service that manages the virtual machines:
vms_service = connection.system_service.vms_service

# List the virtual machines
vms_service.list.each do |vm|
  puts "#{vm.name}: #{vm.id}"
end

# Close the connection to the server:
connection.close
