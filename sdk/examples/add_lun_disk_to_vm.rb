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

# This example will connect to the server and add LUN disk to virtual machine

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:      'https://engine/ovirt-engine/api',
  username: 'admin@internal',
  password: '123456',
  ca_file:  'ca.pem',
  debug:    true,
  log:      Logger.new('example.log')
)

# Locate the virtual machines service and use it to find the virtual
# machine:
vms_service = connection.system_service.vms_service
vm = vms_service.list(search: 'name=myvm').first

# Locate the service that manages the disk attachments of the virtual
# machine:
disk_attachments_service = vms_service.vm_service(vm.id).disk_attachments_service

# Use the "add" method of the disk attachments service to add the LUN disk.
disk_attachments_service.add(
  OvirtSDK4::DiskAttachment.new(
    disk:      {
      name:        'myiscsidisk',
      lun_storage: {
        type:          OvirtSDK4::StorageType::ISCSI,
        logical_units: [{
          address:  '192.168.200.3',
          port:     3260,
          target:   'iqn.2014-07.org.ovirt:storage',
          id:       '36001405fd3728aab74d457c8d185ed2e',
          username: 'username',
          password: 'password'
        }]
      }
    },
    interface: OvirtSDK4::DiskInterface::VIRTIO,
    bootable:  false,
    active:    true
  )
)

# Close the connection to the server:
connection.close
