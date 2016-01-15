#!/usr/bin/ruby

#
# Copyright (c) 2016 Red Hat, Inc.
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

require 'ovirt/sdk/v4'

# This example will connect to the server and attach an existing NFS
# ISO storage domain to a data center.

# Create the connection to the server:
connection = Ovirt::SDK::V4::Connection.new({
  :url => 'https://engine40.example.com/ovirt-engine/api',
  :username => 'admin@internal',
  :password => 'redhat123',
  :ca_file => 'ca.pem',
  :debug => true,
})

# Locate the service that manages the storage domains and use it to
# search for the storage domain:
sds_service = connection.system.storage_domains
sd = sds_service.list({:search => 'name=myiso'})[0]

# Locate the service that manages the data centers and use it to
# search for the data center:
dcs_service = connection.system.data_centers
dc = dcs_service.list({:search => 'name=mydc'})[0]

# Locate the service that manages the data center where we want to
# attach the storage domain:
dc_service = dcs_service.data_center(dc.id)

# Locate the service that manages the storage domains that are attached
# to the data centers:
attached_sds_service = dc_service.storage_domains

# Use the "add" method of service that manages the attached storage
# domains to attach it:
attached_sds_service.add(
  Ovirt::SDK::V4::StorageDomain.new({
    :id => sd.id
  })
)

# Close the connection to the server:
connection.close
