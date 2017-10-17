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

# This example shows how to add a new virtual NIC profile.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Find the root of the tree of services:
system_service = connection.system_service

# Find the network where we want to add the profile. Note that there may be multiple networks with
# the same name, for different data centers, so in order to lookup a network by name we need to do
# it in one specific data center.
dcs_service = system_service.data_centers_service
dc = dcs_service.list(search: 'name=mydc').first
networks = connection.follow_link(dc.networks)
network = networks.detect { |n| n.name == 'mynetwork' }

# Create the virtual NIC profile, with pass-through and port mirroring disabled:
profiles_service = system_service.vnic_profiles_service
profiles_service.add(
  OvirtSDK4::VnicProfile.new(
    name: 'myprofile',
    pass_through: {
      mode: OvirtSDK4::VnicPassThroughMode::DISABLED,
    },
    port_mirroring: false,
    network: {
      id: network.id
    }
  )
)

# Close the connection to the server:
connection.close
