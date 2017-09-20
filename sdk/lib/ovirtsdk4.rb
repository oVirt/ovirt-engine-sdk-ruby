#
# Copyright (c) 2015-2017 Red Hat, Inc.
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

#
# Library requirements.
#
require 'date'

#
# Load the extension:
#
require 'ovirtsdk4c'

#
# Own requirements.
#
require 'ovirtsdk4/version.rb'
require 'ovirtsdk4/errors.rb'
require 'ovirtsdk4/connection.rb'
require 'ovirtsdk4/type.rb'
require 'ovirtsdk4/types.rb'
require 'ovirtsdk4/reader.rb'
require 'ovirtsdk4/readers.rb'
require 'ovirtsdk4/writer.rb'
require 'ovirtsdk4/writers.rb'
require 'ovirtsdk4/service.rb'
require 'ovirtsdk4/services.rb'
require 'ovirtsdk4/probe.rb'
