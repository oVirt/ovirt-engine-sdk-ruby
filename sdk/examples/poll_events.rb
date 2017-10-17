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

# This example shows how to poll the collection of events.

# In order to make sure that no events are lost it is good idea to write in persistent storage the
# index of the last event that we processed. In this example we will store it in a 'index.txt'
# file. In a real world application this should proably be saved in a database.
INDEX_TXT = 'index.txt'.freeze

def write_index(index)
  File.open(INDEX_TXT, 'w') { |f| f.write(index.to_s) }
end

def read_index
  return File.read(INDEX_TXT).to_i if File.exist?(INDEX_TXT)
  nil
end

# This is the function that will be called to process the events, it will just print the identifier
# and the description of the event.
def process_event(event)
  puts("#{event.id} - #{event.description}")
end

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: 'https://engine40.example.com/ovirt-engine/api',
  username: 'admin@internal',
  password: 'redhat123',
  ca_file: 'ca.pem',
  debug: true,
  log: Logger.new('example.log')
)

# Find the root of the tree of services:
system_service = connection.system_service

# Find the service that manages the collection of events:
events_service = system_service.events_service

# If there is no index stored yet, then retrieve the last event and start with it. Events are
# ordered by index, ascending, and 'max=1' requests just one event, so we will get the last event.
unless read_index
  events = events_service.list(max: 1)
  unless events.empty?
    first = events.first
    process_event(first)
    write_index(first.id.to_i)
  end
end

# Do a loop to retrieve events, starting always with the last index, and waiting a bit before
# repeating. Note the use of the 'from' parameter to specify that we want to get events newer than
# the last index that we already processed. Note also that we don't use the 'max' parameter here
# because we want to get all the pending events.
loop do
  sleep(5)
  events = events_service.list(from: read_index)
  events.each do |event|
    process_event(event)
    write_index(event.id.to_i)
  end
end

# Close the connection to the server:
connection.close
