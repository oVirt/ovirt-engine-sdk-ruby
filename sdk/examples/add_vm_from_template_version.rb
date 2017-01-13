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

# This example will connect to the server, and create a virtual machine
# from a specific version of a template.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Get the reference to the root of the tree of services:
system_service = connection.system_service

# Get the reference to the service that manages the storage domains:
storage_domains_service = system_service.storage_domains_service

# Find the storage domain we want to be used for virtual machine disks:
storage_domain = storage_domains_service.list(search: 'name=mydata').first

# Get the reference to the service that manages the templates:
templates_service = system_service.templates_service

# When a template has multiple versions they all have the same name, so
# we need to explicitly find the one that has the version name or
# version number that we want to use. In this case we want to use
# version 3 of the template.
templates = templates_service.list(search: 'name=mytemplate')
template = templates.find { |x| x.version.version_number == 3 }
template_id = template.id

# Find the template disk we want be created on specific storage domain
# for our virtual machine:
template_service = templates_service.template_service(template_id)
disk_attachments = connection.follow_link(template_service.get.disk_attachments)
disk = disk_attachments.first.disk

# Get the reference to the service that manages the virtual machines:
vms_service = system_service.vms_service

# Add a new virtual machine explicitly indicating the identifier of the
# template version that we want to use:
vm = vms_service.add(
  OvirtSDK4::Vm.new(
    name: 'myvm',
    cluster: {
      name: 'mycluster'
    },
    template: {
      id: template_id
    },
    disk_attachments: [{
      disk: {
        id: disk.id,
        format: OvirtSDK4::DiskFormat::COW,
        storage_domains: [{
          id: storage_domain.id
        }]
      }
    }]
  )
)

# Get a reference to the service that manages the virtual machine that
# was created in the previous step:
vm_service = vms_service.vm_service(vm.id)

# Wait till the virtual machine is down, which indicats that all the
# disks have been created:
loop do
  sleep(5)
  vm = vm_service.get
  break if vm.status == OvirtSDK4::VmStatus::DOWN
end

# Close the connection to the server:
connection.close
