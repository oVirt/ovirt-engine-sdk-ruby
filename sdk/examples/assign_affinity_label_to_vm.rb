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

# This example will connect to the server and assign affinity label to virtual machine:

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Get the reference to the "vms" service:
vms_service = connection.system_service.vms_service

# Find the virtual machine:
vm = vms_service.list(search: 'name=myvm').first

# Get the reference to the affinity labels service:
affinity_labels_service = connection.system_service.affinity_labels_service

# Find the affinity label:
affinity_label = affinity_labels_service.list.select { |item| item.name == 'my_affinity_label' }.first

# Locate the service that manages the affinity label
# named `my_affinity_label`:
label_service = affinity_labels_service.label_service(affinity_label.id)

# Get the reference to the service that manages the set
# of virtual machines that have the affinity label
# named `my_affinity_label` assigned:
label_vms_service = label_service.vms_service

# Assign affinity label to virtual machine:
label_vms_service.add(
  OvirtSDK4::Vm.new(
    id: vm.id
  )
)

# Close the connection to the server:
connection.close
