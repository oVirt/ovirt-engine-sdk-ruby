#!/usr/bin/ruby

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

require 'logger'
require 'ovirtsdk4'

# This example will connect to the server and create a new OpenStack
# image provider:

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:      'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file:  'ca.pem',
  debug:    true,
  log:      Logger.new('example.log')
)

# Get the reference to service that manages OpenStack image providers:
providers_service = connection.system_service.openstack_image_providers_service

# Add the new provider:
provider = providers_service.add(
  OvirtSDK4::OpenStackImageProvider.new(
    name:        'myprovider',
    description: 'My provider',
    url:         'http://glance.ovirt.org:9292'
  )
)

# The operation to add the provider returns its representation, so we
# can now print some details:
puts "id: #{provider.id}"
puts "name: #{provider.name}"

# Close the connection to the server:
connection.close
