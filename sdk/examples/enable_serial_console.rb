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

# This example will connect to the server, find a virtual machine and enable the
# serial console if it isn't enabled yet:

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url:      'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file:  'ca.pem',
  debug:    true,
  log:      Logger.new('example.log')
)

# Find the virtual machine. Note the use of the `all_content` parameter, it is
# required in order to obtain additional information that isn't retrieved by
# default, like the configuration of the serial console.
vms_service = connection.system_service.vms_service
vm = vms_service.list(search: 'name=myvm', all_content: true)[0]

# Check if the serial console is enabled, and if it isn't then update the
# virtual machine to enable it:
unless vm.console.enabled
  vm_service = vms_service.vm_service(vm.id)
  vm_service.update(
    console: {
      enabled: true
    }
  )
end

# Close the connection to the server:
connection.close
