#!/usr/bin/ruby

#--
# Copyright (c) 2015 Red Hat, Inc.
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
#++

require 'ovirt/sdk/v4'

# This example will connect to the server, search for a VM by name and
# remove it:

# Create the connection to the server:
connection = Ovirt::SDK::V4::Connection.new({
  :url => 'https://engine40.example.com/ovirt-engine/api',
  :username => 'admin@internal',
  :password => 'redhat123',
  :ca_file => 'ca.pem',
  :debug => false,
})

# Find the service that manages VMs:
vms_service = connection.system.vms

# Find the VM:
vms = vms_service.list({:search => 'name=myvm'})
vm = vms[0]

# Note that the "vm" variable that we assigned above contains only the
# data of the VM, it doesn't have any method like "remove". Methods are
# defined in the services. So now that we have the description of the VM
# we can find the service that manages it, calling the locator method
# "vm" defined in the "vms" service. This locator method receives as
# parameter the identifier of the VM and retursn a reference to the
# service that manages that VM.
vm_service = vms_service.vm(vm.id)

# Now that we have the reference to the service that manages the VM we
# can use it to remove the VM. Note that this method doesn't need any
# parameter, as the identifier of the VM is already known by the service
# that we located in the previous step.
vm_service.remove

# Close the connection to the server:
connection.close
