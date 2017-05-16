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

module OvirtSDK4
  #
  # Instances of this class are returned for operatoins that specify the `wait: false` parameter.
  #
  class Future
    #
    # Creates a new future result.
    #
    # @param connection [Connection] The connection to be used by this future.
    # @param request [HttpRequest] The request that this future will wait for when the `wait` method is called.
    # @param block [Block] The block that will be executed to check the response, and to convert its body into the
    #   right type of object.
    #
    # @api private
    #
    def initialize(connection, request, &block)
      @connection = connection
      @request = request
      @block = block
    end

    #
    # Waits till the result of the operation that created this future is available.
    #
    # @return [Object] The result of the operation that created this future.
    #
    def wait
      response = @connection.wait(@request)
      raise response if response.is_a?(Exception)
      @block.call(response)
    end
  end

  #
  # This is the base class for all the services of the SDK. It contains the utility methods used by all of them.
  #
  class Service
    #
    # Creates a new implementation of the service.
    #
    # @param connection [Connection] The connection to be used by this service.
    #
    # @param path [String] The relative path of this service, for example `vms/123/disks`.
    #
    # @api private
    #
    def initialize(connection, path)
      @connection = connection
      @path = path
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
      body = internal_read_body(response)
      @connection.raise_error(response, body) if body.is_a?(Fault)
      raise Error, "Expected a fault, but got '#{body.class.name.split('::').last}'"
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
      body = internal_read_body(response)
      @connection.raise_error(response, body) if body.is_a?(Fault)
      if body.is_a?(Action)
        return body if body.fault.nil?
        @connection.raise_error(response, body.fault)
      end
      raise Error, "Expected an action or a fault, but got '#{body.class.name.split('::').last}'"
    end

    protected

    #
    # Executes a `get` method.
    #
    # @param specs [Array<Array<Symbol, Symbol, Class>>] An array of arrays containing the names, tags and types of the
    #   parameters.
    # @param opts [Hash] The hash containing the values of the parameters.
    #
    # @api private
    #
    def internal_get(specs, opts)
      headers = opts[:headers] || {}
      query = opts[:query] || {}
      timeout = opts[:timeout]
      wait = opts[:wait]
      wait = true if wait.nil?
      specs.each do |name, kind|
        value = opts[name]
        query[name] = Writer.render(value, kind) if value
      end
      request = HttpRequest.new
      request.method = :GET
      request.url = @path
      request.headers = headers
      request.query = query
      request.timeout = timeout
      @connection.send(request)
      result = Future.new(@connection, request) do |response|
        raise response if response.is_a?(Exception)
        case response.code
        when 200
          internal_read_body(response)
        else
          check_fault(response)
        end
      end
      result = result.wait if wait
      result
    end

    #
    # Executes an `add` method.
    #
    # @param object [Object] The added object.
    # @param type [Class] Type type of the added object.
    # @param specs [Array<Array<Symbol, Symbol, Class>>] An array of arrays containing the names, tags and types of the
    #   parameters.
    # @param opts [Hash] The hash containing the values of the parameters.
    #
    # @api private
    #
    def internal_add(object, type, specs, opts)
      object = type.new(object) if object.is_a?(Hash)
      headers = opts[:headers] || {}
      query = opts[:query] || {}
      timeout = opts[:timeout]
      wait = opts[:wait]
      wait = true if wait.nil?
      specs.each do |name, kind|
        value = opts[name]
        query[name] = Writer.render(value, kind) if value
      end
      request = HttpRequest.new
      request.method = :POST
      request.url = @path
      request.headers = headers
      request.query = query
      request.body = Writer.write(object, indent: true)
      request.timeout = timeout
      @connection.send(request)
      result = Future.new(@connection, request) do |response|
        raise response if response.is_a?(Exception)
        case response.code
        when 200, 201, 202
          internal_read_body(response)
        else
          check_fault(response)
        end
      end
      result = result.wait if wait
      result
    end

    #
    # Executes an `update` method.
    #
    # @param object [Object] The updated object.
    # @param type [Class] Type type of the updated object.
    # @param specs [Array<(Symbol, Symbol, Class)>] An array of tuples containing the names, tags and types of the
    #   parameters.
    # @param opts [Hash] The hash containing the values of the parameters.
    #
    # @api private
    #
    def internal_update(object, type, specs, opts)
      object = type.new(object) if object.is_a?(Hash)
      headers = opts[:headers] || {}
      query = opts[:query] || {}
      timeout = opts[:timeout]
      wait = opts[:wait]
      wait = true if wait.nil?
      specs.each do |name, kind|
        value = opts[name]
        query[name] = Writer.render(value, kind) if value
      end
      request = HttpRequest.new
      request.method = :PUT
      request.url = @path
      request.headers = headers
      request.query = query
      request.body = Writer.write(object, indent: true)
      request.timeout = timeout
      @connection.send(request)
      result = Future.new(@connection, request) do |response|
        raise response if response.is_a?(Exception)
        case response.code
        when 200
          internal_read_body(response)
        else
          check_fault(response)
        end
      end
      result = result.wait if wait
      result
    end

    #
    # Executes a `remove` method.
    #
    # @param specs [Array<(Symbol, Symbol, Class)>] An array of tuples containing the names, tags and types of the
    #   parameters.
    # @param opts [Hash] The hash containing the values of the parameters.
    #
    # @api private
    #
    def internal_remove(specs, opts)
      headers = opts[:headers] || {}
      query = opts[:query] || {}
      timeout = opts[:timeout]
      wait = opts[:wait]
      wait = true if wait.nil?
      specs.each do |name, kind|
        value = opts[name]
        query[name] = Writer.render(value, kind) if value
      end
      request = HttpRequest.new
      request.method = :DELETE
      request.url = @path
      request.headers = headers
      request.query = query
      request.timeout = timeout
      @connection.send(request)
      result = Future.new(@connection, request) do |response|
        raise response if response.is_a?(exception)
        check_fault(response) unless response.code == 200
      end
      result = result.wait if wait
      result
    end

    #
    # Executes an action method.
    #
    # @param path [Symbol] The relative path of the action, for example `:start`.
    # @param member [Symbol] The name of the action member that contains the result. For example `:is_attached`. Can
    #   be `nil` if the action doesn't return any value.
    # @param opts [Hash] The hash containing the parameters of the action.
    #
    # @api private
    #
    def internal_action(path, member, opts)
      headers = opts[:headers] || {}
      query = opts[:query] || {}
      timeout = opts[:timeout]
      wait = opts[:wait]
      wait = true if wait.nil?
      action = Action.new(opts)
      request = HttpRequest.new
      request.method = :POST
      request.url = "#{@path}/#{path}"
      request.headers = headers
      request.query = query
      request.body = Writer.write(action, indent: true)
      request.timeout = timeout
      @connection.send(request)
      result = Future.new(@connection, request) do |response|
        raise response if response.is_a?(Exception)
        case response.code
        when 200
          action = check_action(response)
          action.send(member) if member
        else
          check_action(response)
        end
      end
      result = result.wait if wait
      result
    end

    #
    # Checks the content type of the given response, and if it is XML, as expected, reads the body and converts it
    # to an object. If it isn't XML, then it raises an exception.
    #
    # @param response [HttpResponse] The HTTP response to check.
    # @return [Object] The result of converting the HTTP response body from XML to an SDK object.
    #
    # @api private
    #
    def internal_read_body(response)
      # First check if the response body is empty, as it makes no sense to check the content type if there is
      # no body:
      @connection.raise_error(response, nil) if response.body.nil? || response.body.length.zero?

      # Check the content type, as otherwise the parsing will fail, and the resulting error message won't be explicit
      # about the cause of the problem:
      @connection.check_xml_content_type(response)

      # Parse the XML and generate the SDK object:
      Reader.read(response.body)
    end
  end
end
