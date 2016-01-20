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

# This example will connect to the server and add a new host:

# Create the connection to the server:
connection = Ovirt::SDK::V4::Connection.new({
  :url => 'https://engine40.example.com/ovirt-engine/api',
  :username => 'admin@internal',
  :password => 'redhat123',
  :ca_file => 'ca.pem',
  :debug => true,
})

# Get the reference to the hosts service:
hosts_service = connection.system_service.hosts_service

# Add the host:
host = hosts_service.add(
  Ovirt::SDK::V4::Host.new({
    :name => 'myhost',
    :description => 'My host',
    :address => 'node40.example.com',
    :root_password => 'redhat123',
    :cluster => {
      :name => 'mycluster',
    },
  })
)

# Wait till the host is up:
host_service = hosts_service.host_service(host.id)
begin
  sleep(5)
  host = host_service.get
  state = host.status.state
end while state != Ovirt::SDK::V4::HostStatus::UP

# Close the connection to the server:
connection.close
