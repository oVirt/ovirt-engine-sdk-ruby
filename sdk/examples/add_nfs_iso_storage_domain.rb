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

require 'ovirtsdk4'

# This example will connect to the server and create a new NFS ISO
# storage domain, that won't be initially attached to any data center.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new({
  :url => 'https://engine40.example.com/ovirt-engine/api',
  :username => 'admin@internal',
  :password => 'redhat123',
  :ca_file => 'ca.pem',
  :debug => true,
})

# Get the reference to the storage domains service:
sds_service = connection.system_service.storage_domains_service

# Use the "add" method to create a new NFS storage domain:
sd = sds_service.add(
  OvirtSDK4::StorageDomain.new({
    :name => 'myiso',
    :description => 'My ISO',
    :type => OvirtSDK4::StorageDomainType::ISO,
    :host => {
      :name => 'myhost',
    },
    :storage => {
      :type => OvirtSDK4::StorageType::NFS,
      :address => 'server0.example.com',
      :path => '/nfs/ovirt/40/myiso',
    },
  })
)

# Wait till the storage domain is unattached:
sd_service = sds_service.storage_domain_service(sd.id)
begin
  sleep(5)
  sd = sd_service.get
end while sd.status != OvirtSDK4::StorageDomainStatus::UNATTACHED

# Close the connection to the server:
connection.close
