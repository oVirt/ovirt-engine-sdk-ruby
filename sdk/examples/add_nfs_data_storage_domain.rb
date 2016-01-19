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

# This example will connect to the server and create a new NFS data
# storage domain, that won't be initially attached to any data center.

# Create the connection to the server:
connection = Ovirt::SDK::V4::Connection.new({
  :url => 'https://engine40.example.com/ovirt-engine/api',
  :username => 'admin@internal',
  :password => 'redhat123',
  :ca_file => 'ca.pem',
  :debug => true,
})

# Get the reference to the storage domains service:
sds_service = connection.system.storage_domains

# Create a new NFS storage domain:
sd = sds_service.add(
  Ovirt::SDK::V4::StorageDomain.new({
    :name => 'mydata',
    :description => 'My data',
    :type => Ovirt::SDK::V4::StorageDomainType::DATA,
    :host => {
      :name => 'myhost',
    },
    :storage => {
      :type => Ovirt::SDK::V4::StorageType::NFS,
      :address => 'server0.example.com',
      :path => '/nfs/ovirt/40/mydata',
    },
  })
)

# Wait till the storage domain is unattached:
sd_service = sds_service.storage_domain(sd.id)
begin
  sleep(5)
  sd = sd_service.get
  state = sd.status.state
end while state != Ovirt::SDK::V4::StorageDomainStatus::UNATTACHED

# Close the connection to the server:
connection.close
