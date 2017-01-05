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

# This example will import an exported VM to a target storage domain

# Create connection to the server
connection = OvirtSDK4::Connection.new(
  url: 'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Get the storage domains service
sds_service = connection.system_service.storage_domains_service

# Get the export storage domain
export_sd = sds_service.list(search: 'name=myexport')[0]

# Get the target storage domain
target_sd = sds_service.list(search: 'name=mydata')[0]

# Get the cluster service
cluster_service = connection.system_service.clusters_service

# Locate the cluster to be used for the import
cluster = cluster_service.list(search: 'name=mycluster')[0]

# Get the VMs service for the export storage domain
vms_service = sds_service
              .storage_domain_service(export_sd.id)
              .vms_service

# Get the first exported VM, assuming we have one
exported_vm = vms_service.list[0]

# Import the Vm that was exported to the export storage domain and import it
# to the target storage domain
vms_service.vm_service(exported_vm.id).import(
  storage_domain: OvirtSDK4::StorageDomain.new(
    id: target_sd.id
  ),
  cluster: OvirtSDK4::Cluster.new(
    id: cluster.id
  ),
  vm: OvirtSDK4::Vm.new(
    id: exported_vm.id
  )
)

# Close the connection
connection.close
