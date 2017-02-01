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

# This example checks if a virtual machine has a VNC console, and adds it if it doesn't.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine42.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Find the virtual machine:
vms_service = connection.system_service.vms_service
vm = vms_service.list(search: 'name=myvm').first
vm_service = vms_service.vm_service(vm.id)

# Find the graphics consoles of the virtual machine:
consoles_service = vm_service.graphics_consoles_service
consoles = consoles_service.list

# Add a VNC console if it doesn't exist:
console = consoles.detect { |c| c.protocol == OvirtSDK4::GraphicsType::VNC }
unless console
  consoles_service.add(
    OvirtSDK4::GraphicsConsole.new(
      protocol: OvirtSDK4::GraphicsType::VNC
    )
  )
end

# Close the connection to the server:
connection.close
