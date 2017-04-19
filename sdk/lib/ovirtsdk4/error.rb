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

module OvirtSDK4
  #
  # The class for all errors raised by the SDK.
  #
  class Error
    #
    # An error code associated to the error. For HTTP related errors, this will be the HTTP response code returned by
    # the server. For example, if retrieving of a virtual machine fails because it doesn't exist this attribute will
    # contain the integer value 404. Note that this may be `nil` if the error is not HTTP related.
    #
    # @return [Integer] The HTTP error code.
    #
    attr_accessor :code
  end
end
