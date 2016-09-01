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

# This example will connect to the server and initiate an import of a virtual machine from external VMware system.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new({
  :url => 'https://engine40.example.com/ovirt-engine/api',
  :username => 'admin@internal',
  :password => 'redhat123',
  :ca_file => 'ca.pem',
  :debug => true,
  :log => Logger.new('example.log'),
})

# Get the reference to the service that manages import of external virtual machines:
imports_service = connection.system_service.external_vm_imports_service

# Initiate the import of VM 'myvm' from VMware:
imports_service.add(
  OvirtSDK4::ExternalVmImport.new({
      :name => 'myvm',
      :provider => OvirtSDK4::ExternalVmProviderType::VMWARE,
      :username => 'wmware_user',
      :password => 'wmware123',
      :url => 'vpx://wmware_user@vcenter-host/DataCenter/Cluster/esxi-host?no_verify=1',
      :cluster => {
        :name => 'mycluster'
      },
      :storage_domain => {
        :name => 'mydata'
      },
      :sparse => true,
  })
)

# Close the connection to the server:
connection.close
