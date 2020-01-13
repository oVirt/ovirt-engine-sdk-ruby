#!/usr/bin/ruby

#
# Copyright (c) 2017 Red Hat, Inc.
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

# This example shows how to create a new template importing it from an image available in a Glance storage domain.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:      'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file:  'ca.pem',
  debug:    true,
  log:      Logger.new('example.log')
)

# Get the root of the services tree:
system_service = connection.system_service

# Find the Glance storage domain that is available for default in any
# oVirt installation:
sds_service = system_service.storage_domains_service
sd = sds_service.list(search: 'name=ovirt-image-repository').first

# Find the service that manages the Glance storage domain:
sd_service = sds_service.storage_domain_service(sd.id)

# Find the service that manages the images available in that storage
# domain:
images_service = sd_service.images_service

# The images service doesn't support search, so in order to find the image we need to retrieve all of them and then
# do the filtering explicitly:
image = images_service.list.detect { |i| i.name == 'CirrOS 0.3.4 for x86_64' }

# Find the service that manages the image that we found in the previous step:
image_service = images_service.image_service(image.id)

# Import the image:
image_service.import(
  import_as_template: true,
  template:           {
    name: 'mytemplate'
  },
  cluster:            {
    name: 'mycluster'
  },
  storage_domain:     {
    name: 'mydata'
  }
)

# Close the connection to the server:
connection.close
