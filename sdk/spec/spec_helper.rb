#
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
#

require 'stringio'

require 'ovirt/sdk/v4'

# This is just to shorten the module prefix used in the tests:
SDK = Ovirt::SDK::V4

# This module contains utility functions to be used in all the examples.
module Helpers # :nodoc:
end

# Include the helpers module in all the examples.
RSpec.configure do |c|
  c.include Helpers
end
