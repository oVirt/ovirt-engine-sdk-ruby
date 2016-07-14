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

# This example will connect to the server and list the virtual machines
# using paging:

# Create the connection to the server:
connection = OvirtSDK4::Connection.new({
  :url => 'https://engine40.example.com/ovirt-engine/api',
  :username => 'admin@internal',
  :password => 'redhat123',
  :ca_file => 'ca.pem',
  :debug => true,
  :log => Logger.new('example.log'),
})

# Get the reference to the "vms" service:
vms_service = connection.system_service.vms_service

# List the virtual machines, page by page:
size = 1
index = 1
loop do
  page = vms_service.list({
    :search => "page #{index}",
    :max => size,
  })
  break unless page.length > 0
  page.each do |vm|
    puts("#{vm.name}")
  end
  index += 1
end

# Close the connection to the server:
connection.close
