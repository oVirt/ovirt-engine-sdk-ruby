#--
# Copyright (c) 2015 Red Hat, Inc.
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
#++

##
# Library requirements.
#
require 'date'
require 'stringio'

##
# Load the extension:
require 'ovirtsdk'

##
# Own requirements.
#
require 'ovirt/sdk/v4/version.rb'
require 'ovirt/sdk/v4/xml_formatter.rb'
require 'ovirt/sdk/v4/xml_reader.rb'
require 'ovirt/sdk/v4/xml_writer.rb'
require 'ovirt/sdk/v4/connection.rb'
require 'ovirt/sdk/v4/struct.rb'
require 'ovirt/sdk/v4/list.rb'
require 'ovirt/sdk/v4/fault.rb'
require 'ovirt/sdk/v4/action.rb'
require 'ovirt/sdk/v4/types.rb'
require 'ovirt/sdk/v4/reader.rb'
require 'ovirt/sdk/v4/fault_reader.rb'
require 'ovirt/sdk/v4/action_reader.rb'
require 'ovirt/sdk/v4/readers.rb'
require 'ovirt/sdk/v4/writer.rb'
require 'ovirt/sdk/v4/writers.rb'
require 'ovirt/sdk/v4/service.rb'
require 'ovirt/sdk/v4/services.rb'
