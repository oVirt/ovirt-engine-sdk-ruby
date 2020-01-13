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

# This example shows how to start a virtual machine specifying the boot devices and boot order.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:      'https://engine42.local/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file:  'ca.pem',
  debug:    true,
  log:      Logger.new('example.log')
)

# Find the root of the tree of services:
system_service = connection.system_service

# Find the virtual machine:
vms_service = system_service.vms_service
vm = vms_service.list(search: 'name=myvm').first

# Find the service that manages the virtual machine, as that is where the action methods are
# defined:
vm_service = vms_service.vm_service(vm.id)

# Start the virtual machine explicitly indicating the boot devices and order:
vm_service.start(
  vm: {
    os: {
      boot: {
        devices: [
          OvirtSDK4::BootDevice::NETWORK,
          OvirtSDK4::BootDevice::CDROM
        ]
      }
    }
  }
)

# Wait till the virtual machine is up:
loop do
  sleep(5)
  vm = vm_service.get
  break if vm.status == OvirtSDK4::VmStatus::UP
end

# Close the connection to the server:
connection.close
