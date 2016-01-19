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

# This example will connect to the server and stop a virtual machine.

# Create the connection to the server:
connection = Ovirt::SDK::V4::Connection.new({
  :url => 'https://engine40.example.com/ovirt-engine/api',
  :username => 'admin@internal',
  :password => 'redhat123',
  :ca_file => 'ca.pem',
  :debug => true,
})

# Get the reference to the "vms" service:
vms_service = connection.system.vms

# Find the virtual machine:
vm = vms_service.list({:search => 'name=myvm'})[0]

# Locate the service that manages the virtual machine, as that is where
# the action methods are defined:
vm_service = vms_service.vm(vm.id)

# Call the "stop" method of the service to stop it:
vm_service.stop

# Wait till the virtual machine is down:
begin
  sleep(5)
  vm = vm_service.get
  state = vm.status.state
end while state != Ovirt::SDK::V4::VmStatus::DOWN

# Close the connection to the server:
connection.close
