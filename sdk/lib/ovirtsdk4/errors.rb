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
  # The base class for all errors raised by the SDK.
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

    #
    # The `Fault` object associated to the error.
    #
    # @return [Fault] The fault object associated to the error, if a fault was provided by the server, `nil` otherwise.
    #
    attr_accessor :fault
  end

  #
  # This class of error indicates that an authentiation or authorization problem happenend, like incorrect user name,
  # incorrect password, or missing permissions.
  #
  class AuthError < Error
  end

  #
  # This class of error indicates that the name of the server or the name of the proxy can't be resolved to an IP
  # address, or that the connection can't be stablished because the server is down or unreachable.
  #
  # Note that for this class of error the `code` and `fault` attributes will always be empty, as no response from the
  # server will be available to populate them.
  #
  class ConnectionError < Error
  end

  #
  # This class of error indicates that an object can't be found.
  #
  class NotFoundError < Error
  end

  #
  # This class of error indicates that an operation timed out.
  #
  # Note that for this class of error the `code` and `fault` attributes will always be empty, as no response from the
  # server will be available to populate them.
  #
  class TimeoutError < Error
  end
end
