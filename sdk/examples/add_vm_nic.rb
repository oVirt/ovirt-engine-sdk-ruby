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

# This example will connect to the server and add a network interface
# card to an existing virtual machine.

# Create the connection to the server:
connection = Ovirt::SDK::V4::Connection.new({
  :url => 'https://engine40.example.com/ovirt-engine/api',
  :username => 'admin@internal',
  :password => 'redhat123',
  :ca_file => 'ca.pem',
  :debug => true,
})

# Locate the virtual machines service and use it to find the virtual
# machine:
vms_service = connection.system.vms
vm = vms_service.list({:search => 'name=myvm'})[0]

# In order to specify the network that the new interface will be
# connected to we need to specify the identifier of the virtual network
# interface profile, so we need to find it:
profiles_service = connection.system.vnic_profiles
profile_id = nil
profiles_service.list.each do |profile|
  if profile.name == 'mynetwork'
    profile_id = profile.id
    break
  end
end

# Locate the service that manages the network interface cards of the
# virtual machine:
nics_service = vms_service.vm(vm.id).nics

# Use the "add" method of the network interface cards service to add the
# new network interface card:
nics_service.add(
  Ovirt::SDK::V4::Nic.new({
    :name => 'mynic',
    :description => 'My network interface card',
    :vnic_profile => {
      :id => profile_id
    },
  })
)

# Close the connection to the server:
connection.close
