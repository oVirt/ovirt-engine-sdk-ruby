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

# This example will connect to the server and create a new virtual
# machine from a template. The disks of the new virtual machine will
# be cloned, so that it will be independent of the template.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:      'https://engine41.local/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file:  'ca.pem',
  debug:    true,
  log:      Logger.new('example.log')
)

# Get the reference to the "vms" service:
vms_service = connection.system_service.vms_service

# Use the "clone" parameter of the "add" method to request that the
# disks of the new virtual machine are independent of the template.
vm = OvirtSDK4::Vm.new(
  name:     'myclonedvm',
  cluster:  {
    name: 'mycluster'
  },
  template: {
    name: 'mytemplate'
  }
)
vms_service.add(vm, clone: true)

# Close the connection to the server:
connection.close
