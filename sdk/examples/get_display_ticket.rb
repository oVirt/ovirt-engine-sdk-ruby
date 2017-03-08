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

# This example shows how to get a display ticket for a virtual machine. Note that a virtual machine may have multiple
# graphics consoles, each one implementing a different access protocol. For example, the same machine may have VNC
# and SPICE graphics consoles enabled simultaneously. In order to get a ticket the access protocol has to be selected
# explicitly.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine42.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Get the reference to the root of the tree of services:
system_service = connection.system_service

# Find the virtual machine:
vms_service = system_service.vms_service
vm = vms_service.list(search: 'name=myvm').first

# Find the service that manages the graphics consoles of the virtual machine:
vm_service = vms_service.vm_service(vm.id)
consoles_service = vm_service.graphics_consoles_service

# The method that lists the graphics consoles doesn't support search, so in order to find the console corresponding
# to the access protocol that we are interested on (SPICE in this example) we need to get all of them and filter
# explicitly. In addition the `current` parameter must be `true`, as otherwise you will *not* get important
# values like the `address` and `port` where the console is available.
console = consoles_service.list(current: true).detect { |c| c.protocol == OvirtSDK4::GraphicsType::SPICE }

# Find the service that manages the graphics console that was selected in the previous step:
console_service = consoles_service.console_service(console.id)

# Request the ticket. The virtual machine must be up and running, as it doesn't make sense to get a console ticket
# for a virtual machine that is down. If you try that, the request will fail.
ticket = console_service.ticket

# Print the details needed to connect to the console (the ticket value is the password):
puts "address: #{console.address}"
puts "port: #{console.port}"
puts "tls_port: #{console.tls_port}"
puts "password: #{ticket.value}"

# Close the connection to the server:
connection.close
