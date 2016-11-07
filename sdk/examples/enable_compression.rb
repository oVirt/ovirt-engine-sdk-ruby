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

# This example shows how to enable compression of the responses sent by
# the server.

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  compress: false,
  debug: false,
  log: Logger.new('example.log')
)

# Note that even when compression is enabled the server may decide to
# ignore it, and may send uncompressed results.

# Note also that compression and debug aren't compatible. When debug is
# enabled compression is automatically disabled, as otherwise the debug
# output would be compressed as well, and useless.

# Get some data:
api = connection.system_service.get
puts(api.product_info.version.full_version)

# Close the connection to the server:
connection.close
