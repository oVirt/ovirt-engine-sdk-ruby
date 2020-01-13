#!/usr/bin/ruby

#
# Copyright (c) 2016-2017 Red Hat, Inc.
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

# This example show how to add a network interface card to an existing virtual machine.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:      'https://engine40.example.com/ovirt-engine/api',
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

# In order to specify the network that the new NIC will be connected to, we need to specify the
# identifier of the virtual NIC profile. But there may be multiple profiles with the same name, for
# different data centers, for example. So first we need to find the the networks that are available
# in the cluster that the virtual machine belongs to.
cluster = connection.follow_link(vm.cluster)
networks = connection.follow_link(cluster.networks)
network_ids = networks.map(&:id)

# Now that we know what networks are available in the cluster, we can select a virtual NIC profile
# that corresponds to one of those networks, and has the name that we want to use. Note that the
# system automatically creates a virtual NIC profile for each network, with the same name than the
# network, so usually this name will be name of the network.
profiles_service = system_service.vnic_profiles_service
profiles = profiles_service.list
profile = profiles.detect { |p| network_ids.include?(p.network.id) && p.name == 'myprofile' }

# Locate the service that manages the collection network interface cards of the virtual machine:
nics_service = vms_service.vm_service(vm.id).nics_service

# Add the new network interface card:
nics_service.add(
  OvirtSDK4::Nic.new(
    name:         'mynic',
    description:  'My network interface card',
    vnic_profile: {
      id: profile.id
    }
  )
)

# Close the connection to the server:
connection.close
