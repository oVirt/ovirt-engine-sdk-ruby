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

# This example will connect to the server and print the names and identifiers of all the virtual machines:

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

# Use the "list" method of the "vms" service to list all the virtual machines of the system:
vms = vms_service.list

# Print the virtual machine names and identifiers:
vms.each do |vm|
  puts "#{vm.name}: #{vm.id}"
end

# Close the connection to the server:
connection.close
