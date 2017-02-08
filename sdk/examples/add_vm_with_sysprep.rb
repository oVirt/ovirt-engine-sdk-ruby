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

# This example will create a new virtual machine and start it using Sysprep:

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Find the service that manages the collection of virtual machines:
vms_service = connection.system_service.vms_service

# Create the virtual machine. Note that no sysprep stuff is needed here, when creating it, it will be used later, when
# starting it.
vm = vms_service.add(
  OvirtSDK4::Vm.new(
    name: 'myvm',
    cluster: {
      name: 'mycluster'
    },
    template: {
      name: 'mytemplate'
    }
  )
)

# Find the service that manages the virtual machine:
vm_service = vms_service.vm_service(vm.id)

# Wait till the virtual machine is down, which indicats that all the disks have been created:
loop do
  sleep(5)
  vm = vm_service.get
  break if vm.status == OvirtSDK4::VmStatus::DOWN
end

# The content of the Unattend.xml file. Note that this is an incomplete file, make sure to use a complete one, maybe
# reading it from an external file.
unattend_xml = '
<?xml version="1.0" encoding="UTF-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  ...
</unattend>
'.freeze

# Start the virtual machine enabling sysprep. Make sure to use a Windows operating system, either in the template, or
# overriding it explicitly here. Without that the Sysprep logic won't be triggered.
vm_service.start(
  use_sysprep: true,
  vm: {
    os: {
      type: 'windows_7x64'
    },
    initialization: {
      custom_script: unattend_xml
    }
  }
)

# Close the connection to the server:
connection.close
