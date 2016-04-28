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
    # Reads the response body assuming that it contains a fault message, converts it to an Error and raises it.
    #
    # This method is intended for internal use by other components of the SDK. Refrain from using it directly, as
    # backwards compatibility isn't guaranteed.
    #
    # @api private
    #
    def check_fault(response)
      begin
        reader = XmlReader.new(response.body)
        fault = FaultReader.read_one(reader)
      ensure
        reader.close
      end
      raise_error(response, fault)
    end

    #
    # Reads the response body assuming that it contains an action, checks if it contains a fault message, and if it
    # does converts it to an Error and raises it. If it doesn't contain a fault then it just returns the action object.
    #
    # This method is intended for internal use by other components of the SDK. Refrain from using it directly, as
    # backwards compatibility isn't guaranteed.
    #
    # @api private
    #
    def check_action(response)
      begin
        reader = XmlReader.new(response.body)
        action = ActionReader.read_one(reader)
      ensure
        reader.close
      end
      unless action.fault.nil?
        raise_error(response, action.fault)
      end
      return action
    end

  end

end
