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

# This example will connect to the server and create a new cluster:

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Get the reference to the disks service:
disks_service = connection.system_service.disks_service

# Add the disk. Note that the size of the disk, the `provisioned_size`
# attribute, is specified in bytes, so to create a disk of 10 GiB the
# value should be 10 * 2^30.
disk = disks_service.add(
  name: 'mydisk',
  description: 'My disk',
  format: OvirtSDK4::DiskFormat::COW,
  provisioned_size: 10 * 2**30,
  storage_domains: [{
    name: 'mydata'
  }]
)

# Wait till the disk is completely created:
disk_service = disks_service.disk_service(disk.id)
loop do
  sleep(5)
  disk = disk_service.get
  break if disk.status == OvirtSDK4::DiskStatus::OK
end

# Close the connection to the server:
connection.close
