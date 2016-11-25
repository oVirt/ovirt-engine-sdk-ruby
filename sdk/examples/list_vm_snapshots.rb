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

#
# This example will connect to the server and list all the snapshots
# that exist on the system. The output will be simimar to this:
#
# myvm:My first snapshot:mydisk:mydata
# myvm:My second snapshot:mydisk:mydata
# yourvm:Your first snapshot:yourdisk:yourdata
# ...
#
# The first column is the name of the virtual machine. The second is the
# name of the snapshot. The third one is the name of the disk. The
# fourth one is the name of the storage domain where the disk is stored.
#

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Get the reference to the root service:
system_service = connection.system_service

# Find all the virtual machines and store the id and name in a
# hash, so that looking them up later will be faster:
vms_service = system_service.vms_service
vms_map = Hash[vms_service.list.map { |vm| [vm.id, vm.name] }]

# Same for storage domains:
sds_service = system_service.storage_domains_service
sds_map = Hash[sds_service.list.map { |sd| [sd.id, sd.name] }]

# For each virtual machine find its snapshots, then for each snapshot
# find its disks:
vms_map.each do |vm_id, vm_name|
  vm_service = vms_service.vm_service(vm_id)
  snaps_service = vm_service.snapshots_service
  snaps_map = Hash[snaps_service.list.map { |snap| [snap.id, snap.description] }]
  snaps_map.each do |snap_id, snap_description|
    snap_service = snaps_service.snapshot_service(snap_id)
    disks_service = snap_service.disks_service
    disks_service.list.each do |disk|
      next unless disk.storage_domains.any?
      sd_id = disk.storage_domains.first.id
      sd_name = sds_map[sd_id]
      puts "#{vm_name}:#{snap_description}:#{disk.alias_}:#{sd_name}"
    end
  end
end

# Close the connection to the server:
connection.close
