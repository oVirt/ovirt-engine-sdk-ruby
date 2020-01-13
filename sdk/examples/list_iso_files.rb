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

# This example shows how to list all the .iso files available in an ISO storage domain:

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

# Find the service that manages the collection of storage domains:
sds_service = system_service.storage_domains_service

# Find the ISO storage domain:
sd = sds_service.list(search: 'name=myiso').first

# Find the service that manages the ISO storage domain:
sd_service = sds_service.storage_domain_service(sd.id)

# Find the service that manages the collection of files available in the storage domain:
files_service = sd_service.files_service

# List the names of the files. Note that the name of the .iso file is contained in the `id`
# attribute.
files = files_service.list
files.each do |file|
  puts file.id
end

# Close the connection to the server:
connection.close
