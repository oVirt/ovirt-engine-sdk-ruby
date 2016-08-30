#
# Copyright (c) 2015-2016 Red Hat, Inc.
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
  # This is the base class for all the services of the SDK. It contains the utility methods used by all of them.
  #
  class Service

    #
    # Creates and raises an error containing the details of the given HTTP response and fault.
    #
    # This method is intended for internal use by other components of the SDK. Refrain from using it directly, as
    # backwards compatibility isn't guaranteed.
    #
    # @api private
    #
    def raise_error(response, fault)
      message = ''
      unless fault.nil?
        unless fault.reason.nil?
          message << ' ' unless message.empty?
          message << "Fault reason is \"#{fault.reason}\"."
        end
        unless fault.detail.nil?
          message << ' ' unless message.empty?
          message << "Fault detail is \"#{fault.detail}\"."
        end
      end
      unless response.nil?
        unless response.code.nil?
          message << ' ' unless message.empty?
          message << "HTTP response code is #{response.code}."
        end
        unless response.message.nil?
          message << ' ' unless message.empty?
          message << "HTTP response message is \"#{response.message}\"."
        end
      end
      raise Error.new(message)
    end

    #
    # Reads the response body, checks if it is a fault and if so converts it to an Error and raises it.
    #
    # This method is intended for internal use by other components of the SDK. Refrain from using it directly, as
    # backwards compatibility isn't guaranteed.
    #
    # @api private
    #
    def check_fault(response)
      body = response.body
      if body.nil? || body.length == 0
        raise_error(response, nil)
      end
      body = Reader.read(body)
      if body.is_a?(Fault)
        raise_error(response, body)
      end
      raise Error.new("Expected a fault, but got '#{body.class.name.split('::').last}'")
    end

    #
    # Reads the response body and checks if it is an action or a fault. If it is an action it checks if the action
    # contains a nested fault. If there is a fault then converts it to an `Error` and raises it. If there is no fault
    # then the action object is returned.
    #
    # This method is intended for internal use by other components of the SDK. Refrain from using it directly, as
    # backwards compatibility isn't guaranteed.
    #
    # @api private
    #
    def check_action(response)
      body = response.body
      if body.nil? || body.length == 0
        raise_error(response, nil)
      end
      body = Reader.read(body)
      if body.is_a?(Fault)
        raise_error(response, body)
      end
      if body.is_a?(Action)
        return body if body.fault.nil?
        raise_error(response, body.fault)
      end
      raise Error.new("Expected an action or a fault, but got '#{body.class.name.split('::').last}'")
    end

  end

end
