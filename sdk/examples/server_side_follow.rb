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

# This example shows how to use the `follow` parameter to retrieve a virtual machine with its disks
# and network interface cards using a single request. Note that this `follow` parameter is only
# available since version 4.2 of the server. If the `follow` parameter is passed to a version of the
# server older than 4.2, it will silently ignore it.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine42.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Get the reference to the service that manages the collection of virtual machines:
vms_service = connection.system_service.vms_service

# Find the virtual machine. By using the `follow` parameter we request the server to return the
# disks and network interface cards as part of the response.
vm = vms_service.list(
  search: 'name=myvm',
  follow: 'disk_attachments.disk,nics'
).first

# The details of the disks and the network interfaces will now be available without having to send
# additional requests to the server:
vm.disk_attachments.each do |attachment|
  puts("disk: #{attachment.disk.name}")
end
vm.nics.each do |nic|
  puts("nic: #{nic.name}")
end

# Close the connection:
connection.close
