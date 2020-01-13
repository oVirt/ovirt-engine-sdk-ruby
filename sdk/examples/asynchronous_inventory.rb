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

# This example shows how to use the asynchronous and pipelining capabilities of the SDK to download from the server
# large amounts of data in an efficient way. A typical use case for this is the download of the complete inventory of
# hosts and virtual machines.

# This combination of pipeline size and number of connections gives good results in large scale environments:
pipeline = 40
connections = 10

# Requests are sent in blocks, and the size of each block shoul be the number of connections multipled by the size
# of the pipeline:
block = connections * pipeline

# This function takes a list of objects and creates a hash where the keys are the identifiers and the values are
# the objects. We will use it to create indexes that we can use to speed up things like finding the disks
# corresponding to a virtual machine, given their identifiers.
def index(list)
  index = {}
  list.each do |item|
    index[item.id] = item
  end
  index
end

# Connection options shared by all the connections that we will use:
connection_opts = {
  url:      'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file:  'ca.pem',
  log:      Logger.new('example.log')
}

# In order to download large collections of objects, it is convenient to use a different HTTP connection for each of
# them, so that they are downloaded in parallel. To achieve that we need to configure the connection so that it uses
# multiple HTTP connections, but not pipelining, as otherwise those requests will be pipelined and executed serially by
# the server.
connection = OvirtSDK4::Connection.new(
  connection_opts.merge(
    connections: connections,
    pipeline:    0
  )
)

# Get the reference to root of the services tree:
system_service = connection.system_service

# Send requests for all the collections, but don't wait for the results. This way the requests will be sent
# simultaneously, using the multiple connections.
puts('Requesting data...')
dcs_future = system_service.data_centers_service.list(wait: false)
clusters_future = system_service.clusters_service.list(wait: false)
sds_future = system_service.storage_domains_service.list(wait: false)
nets_future = system_service.networks_service.list(wait: false)
hosts_future = system_service.hosts_service.list(wait: false)
vms_future = system_service.vms_service.list(wait: false)
disks_future = system_service.disks_service.list(wait: false)

# Wait for the results of the requests that we sent. The calls to the `wait` method will perform all the work, for all
# the pending requests, and will eventually return the requested data.
puts('Waiting for data centers ...')
dcs = dcs_future.wait
puts("Loaded #{dcs.length} data centers.")

puts('Waiting for clusters...')
clusters = clusters_future.wait
puts("Loaded #{clusters.length} clusters.")

puts('Waiting for storage domains...')
sds = sds_future.wait
puts("Loaded #{sds.length} storage domains.")

puts('Waiting for networks ...')
nets = nets_future.wait
puts("Loaded #{nets.length} networks.")

puts('Waiting for hosts ...')
hosts = hosts_future.wait
puts("Loaded #{hosts.length} hosts.")

puts('Waiting for VMs ...')
vms = vms_future.wait
vms_index = index(vms)
puts("Loaded #{vms.length} VMs.")

puts('Waiting for disks ...')
disks = disks_future.wait
disks_index = index(disks)
puts("Loaded #{disks.length} disks.")

# Close the connection that we used for large collections of objects, as we need a new one, configured differently, for
# the small objects:
connection.close

# For small objects we are going to send many small requests, and in this case we want to use multiple connections *and*
# pipelining:
connection = OvirtSDK4::Connection.new(
  connection_opts.merge(
    connections: connections,
    pipeline:    pipeline
  )
)

# Note that the when the previous connection was closed, all the references to services obtained from it were also
# invalidated, so we need to get them again.
system_service = connection.system_service
vms_service = system_service.vms_service

# We need now to iterate the collection of VMs that we already have in memory, block by block, and for each block send
# the requests to get the disks attachments, without waiting for the responses. This way those requests will distributed
# amongst the multiple connections, and will be added to the pipelines. It is necessary to do this block by block
# because otherwise, if we send all the requests at once, the requests that can't be added to the pipelines of the
# connections wold be queued in memory, wasting expensive resources of the underlying library. After sending each block
# of requests, we need to wait for the responses.
puts('Loading VM disk attachments ...')
vms.each_slice(block) do |vms_slice|
  atts_futures = {}
  vms_slice.each do |vm|
    vm_service = vms_service.vm_service(vm.id)
    atts_service = vm_service.disk_attachments_service
    atts_future = atts_service.list(wait: false)
    atts_futures[vm.id] = atts_future
  end
  atts_futures.each do |vm_id, atts_future|
    vm = vms_index[vm_id]
    vm.disk_attachments = atts_future.wait
    vm.disk_attachments.each do |att|
      att.disk = disks_index[att.disk.id]
      puts("Loaded disk attachments of VM '#{vm.name}'.")
    end
  end
end
puts('Loaded VM disk attachments.')

# Load the VM NICs:
puts('Loading VM NICs ...')
vms.each_slice(block) do |vms_slice|
  nics_futures = {}
  vms_slice.each do |vm|
    vm_service = vms_service.vm_service(vm.id)
    nics_service = vm_service.nics_service
    nics_future = nics_service.list(wait: false)
    nics_futures[vm.id] = nics_future
  end
  nics_futures.each do |vm_id, nics_future|
    vm = vms_index[vm_id]
    vm.nics = nics_future.wait
    puts("Loaded NICs of VM '#{vm.name}'.")
  end
end
puts('Loaded VM NICs.')

# Load the VM reported devices:
puts('Loading VM reported devices ...')
vms.each_slice(block) do |vms_slice|
  devices_futures = {}
  vms_slice.each do |vm|
    vm_service = vms_service.vm_service(vm.id)
    devices_service = vm_service.reported_devices_service
    devices_future = devices_service.list(wait: false)
    devices_futures[vm.id] = devices_future
  end
  devices_futures.each do |vm_id, devices_future|
    vm = vms_index[vm_id]
    vm.reported_devices = devices_future.wait
    puts("Loaded reported devices of VM '#{vm.name}'.")
  end
end
puts('Loaded VM reported devices.')

# Close the connection:
connection.close
