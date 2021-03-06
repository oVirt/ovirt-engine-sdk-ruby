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

# This example will connect to the server and start a virtual machine.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:      'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file:  'ca.pem',
  debug:    true,
  log:      Logger.new('example.log')
)

# Get the reference to the "vms" service:
vms_service = connection.system_service.vms_service

# Find the virtual machine:
vm = vms_service.list(search: 'name=myvm')[0]

# Locate the service that manages the virtual machine:
vm_service = vms_service.vm_service(vm.id)

# Locate the service that manages the CDROM devices of the VM:
cdroms_service = vm_service.cdroms_service

# Get the first found CDROM:
cdrom = cdroms_service.list[0]

# Locate the service that manages the CDROM device found in previous step
# of the VM:
cdrom_service = cdroms_service.cdrom_service(cdrom.id)

# Change the CD of the VM to 'my_iso_file.iso'. By default the below
# operation change permanently the disk that will be visible to the
# virtual machine after the next boot, but they don't have any effect
# on the currently running virtual machine. If you want to change the
# disk that is visible to the current running virtual machine, change
# the `current` parameter's value to `true`.
cdrom_service.update(
  OvirtSDK4::Cdrom.new(
    file: {
      id: 'CentOS-7-x86_64-DVD-1511.iso'
    }
  ),
  current: false
)

# Close the connection to the server:
connection.close
