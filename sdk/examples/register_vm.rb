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

# This example will connect to the server and register a virtual machine.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Get the reference to the "storage_domains" service:
storage_domains_service = connection.system_service.storage_domains_service

# Find the storage domain with unregistered VM:
sd = storage_domains_service.list(search: 'name=mysd').first

# Locate the service that manages the storage domain, as that is where
# the action methods are defined:
storage_domain_service = storage_domains_service.storage_domain_service(sd.id)

# Locate the service that manages the VMs in storage domain:
vms_service = storage_domain_service.vms_service

# Find the the unregistered VM we want to register:
vms = vms_service.list(unregistered: true)
vm = vms.detect { |v| v.name == 'myvm' }

# Locate the service that manages virtual machine in the storage domain,
# as that is where the action methods are defined:
vm_service = vms_service.vm_service(vm.id)

# Register the VM into the system:
vm_service.register(
  cluster: {
    name: 'mycluster'
  },
  vm: {
    name: 'exported_myvm'
  },
  vnic_profile_mappings: [{
    source_network_name: 'mynetwork',
    source_network_profile_name: 'mynetwork',
    target_vnic_profile: {
      name: 'mynetwork'
    }
  }],
  reassign_bad_macs: true
)

# Close the connection to the server:
connection.close
