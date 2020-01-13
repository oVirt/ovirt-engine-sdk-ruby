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

# This example configures the networking of a host, adding a bonded interface and attaching it to a network with
# an static IP address.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:      'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file:  'ca.pem',
  debug:    true,
  log:      Logger.new('example.log')
)

# Find the service that manages the collection of hosts:
hosts_service = connection.system_service.hosts_service

# Find the host:
host = hosts_service.list(search: 'name=myhost').first

# Find the service that manages the host:
host_service = hosts_service.host_service(host.id)

# Configure the network adding a bond with two slaves and attaching it to a network with an static IP address:
host_service.setup_networks(
  modified_bonds:               [
    {
      name:    'bond0',
      bonding: {
        options: [
          {
            name:  'mode',
            value: '1'
          },
          {
            name:  'miimon',
            value: '100'
          }
        ],
        slaves:  [
          {
            name: 'eth1'
          },
          {
            name: 'eth2'
          }
        ]
      }
    }
  ],
  modified_network_attachments: [
    {
      network:                {
        name: 'mynetwork'
      },
      host_nic:               {
        name: 'bond0'
      },
      ip_address_assignments: [
        {
          assignment_method: OvirtSDK4::BootProtocol::STATIC,
          ip:                {
            address: '192.168.122.100',
            netmask: '255.255.255.0'
          }
        }
      ]
    }
  ]
)

# After modifying the network configuration it is very important to make it persistent:
host_service.commit_net_config

# Close the connection to the server:
connection.close
