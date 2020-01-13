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
    # @param service [Service] The service that created this future.
    # @param request [HttpRequest] The request that this future will wait for when the `wait` method is called.
    # @param block [Block] The block that will be executed to check the response, and to convert its body into the
    #   right type of object.
    #
    # @api private
    #
    def initialize(service, request, &block)
      @service = service
      @request = request
      @block = block
    end

    #
    # Waits till the result of the operation that created this future is available.
    #
    # @return [Object] The result of the operation that created this future.
    #
    def wait
      response = @service.connection.wait(@request)
      raise response if response.is_a?(Exception)

      @block.call(response)
    end

    #
    # Returns a string representation of the future.
    #
    # @return [String] The string representation.
    #
    def inspect
      "#<#{self.class.name}:#{@request.method} #{@request.url}>"
    end

    #
    # Returns a string representation of the future.
    #
    # @return [String] The string representation.
    #
    def to_s
      inspect
    end
  end

  #
  # This is the base class for all the services of the SDK. It contains the utility methods used by all of them.
  #
  class Service
    #
    # Creates a new implementation of the service.
    #
    # @param parent [Service, Connection] The parent of this service. For most services the parent will be another
    #   service. For example, for the `vm` service that manages virtual machine `123` the parent will be the `vms`
    #   service that manages the collection of virtual machines. For the root of the services tree the parent will
    #   be the connection.
    #
    # @param path [String] The path of this service, relative to its parent. For example, the path of the `vm`
    #   service that manages virtual machine `123` will be `vm/123`.
    #
    # @api private
    #
    def initialize(parent, path)
      @parent = parent
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
      connection.raise_error(response, body) if body.is_a?(Fault)
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
      connection.raise_error(response, body) if body.is_a?(Fault)
      if body.is_a?(Action)
        return body if body.fault.nil?

        connection.raise_error(response, body.fault)
      end
      raise Error, "Expected an action or a fault, but got '#{body.class.name.split('::').last}'"
    end

    #
    # Returns the connection used by this service.
    #
    # This method is intended for internal use by other components of the SDK. Refrain from using it directly, as
    # backwards compatibility isn't guaranteed.
    #
    # @return [Connection] The connection used by this service.
    #
    # @api private
    #
    def connection
      return @parent if @parent.is_a? Connection

      @parent.connection
    end

    #
    # Returns a string representation of the service.
    #
    # @return [String] The string representation.
    #
    def inspect
      "#<#{self.class.name}:#{absolute_path}>"
    end

    #
    # Returns a string representation of the service.
    #
    # @return [String] The string representation.
    #
    def to_s
      inspect
    end

    protected

    #
    # Executes a `get` method.
    #
    # @param specs [Array<Array<Symbol, Class>>] An array of arrays containing the names and types of the parameters.
    # @param opts [Hash] The hash containing the values of the parameters.
    #
    # @api private
    #
    def internal_get(specs, opts)
      # Get the values of the built-in options:
      headers = opts.delete(:headers) || {}
      query = opts.delete(:query) || {}
      timeout = opts.delete(:timeout)
      wait = opts.delete(:wait)
      wait = true if wait.nil?

      # Get the values of the options specific to this operation:
      specs.each do |name, kind|
        value = opts.delete(name)
        query[name] = Writer.render(value, kind) unless value.nil?
      end

      # Check the remaining options:
      check_bad_opts(specs, opts)

      # Create and send the request:
      request = HttpRequest.new
      request.method = :GET
      request.url = absolute_path
      request.headers = headers
      request.query = query
      request.timeout = timeout
      connection.send(request)
      result = Future.new(self, request) do |response|
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
    # @param specs [Array<Array<Symbol, Class>>] An array of arrays containing the names and types of the parameters.
    # @param opts [Hash] The hash containing the values of the parameters.
    #
    # @api private
    #
    def internal_add(object, type, specs, opts)
      # Get the values of the built-in options:
      object = type.new(object) if object.is_a?(Hash)
      headers = opts.delete(:headers) || {}
      query = opts.delete(:query) || {}
      timeout = opts.delete(:timeout)
      wait = opts.delete(:wait)
      wait = true if wait.nil?

      # Get the values of the options specific to this operation:
      specs.each do |name, kind|
        value = opts.delete(name)
        query[name] = Writer.render(value, kind) unless value.nil?
      end

      # Check the remaining options:
      check_bad_opts(specs, opts)

      # Create and send the request:
      request = HttpRequest.new
      request.method = :POST
      request.url = absolute_path
      request.headers = headers
      request.query = query
      request.body = Writer.write(object, indent: true)
      request.timeout = timeout
      connection.send(request)
      result = Future.new(self, request) do |response|
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
    # @param specs [Array<Array<Symbol, Class>>] An array of tuples containing the names and types of the parameters.
    # @param opts [Hash] The hash containing the values of the parameters.
    #
    # @api private
    #
    def internal_update(object, type, specs, opts)
      # get the values of the built-in options:
      object = type.new(object) if object.is_a?(Hash)
      headers = opts.delete(:headers) || {}
      query = opts.delete(:query) || {}
      timeout = opts.delete(:timeout)
      wait = opts.delete(:wait)
      wait = true if wait.nil?

      # Get the values of the options specific to this operation:
      specs.each do |name, kind|
        value = opts.delete(name)
        query[name] = Writer.render(value, kind) unless value.nil?
      end

      # Check the remaining options:
      check_bad_opts(specs, opts)

      # Create and send the request:
      request = HttpRequest.new
      request.method = :PUT
      request.url = absolute_path
      request.headers = headers
      request.query = query
      request.body = Writer.write(object, indent: true)
      request.timeout = timeout
      connection.send(request)
      result = Future.new(self, request) do |response|
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
    # @param specs [Array<Array<Symbol, Class>>] An array of tuples containing the names and types of the  parameters.
    # @param opts [Hash] The hash containing the values of the parameters.
    #
    # @api private
    #
    def internal_remove(specs, opts)
      # Get the values of the built-in options:
      headers = opts.delete(:headers) || {}
      query = opts.delete(:query) || {}
      timeout = opts.delete(:timeout)
      wait = opts.delete(:wait)
      wait = true if wait.nil?

      # Get the values of the options specific to this operation:
      specs.each do |name, kind|
        value = opts.delete(name)
        query[name] = Writer.render(value, kind) unless value.nil?
      end

      # Check the remaining options:
      check_bad_opts(specs, opts)

      # Create and send the request:
      request = HttpRequest.new
      request.method = :DELETE
      request.url = absolute_path
      request.headers = headers
      request.query = query
      request.timeout = timeout
      connection.send(request)
      result = Future.new(self, request) do |response|
        raise response if response.is_a?(Exception)

        check_fault(response) unless response.code == 200
      end
      result = result.wait if wait
      result
    end

    #
    # Executes an action method.
    #
    # @param name [Symbol] The name of the action, for example `:start`.
    # @param member [Symbol] The name of the action member that contains the result. For example `:is_attached`. Can
    #   be `nil` if the action doesn't return any value.
    # @param specs [Array<Array<Symbol, Class>>] An array of tuples containing the names and types of the parameters.
    # @param opts [Hash] The hash containing the parameters of the action.
    #
    # @api private
    #
    def internal_action(name, member, specs, opts)
      # Get the values of the built-in options:
      headers = opts.delete(:headers) || {}
      query = opts.delete(:query) || {}
      timeout = opts.delete(:timeout)
      wait = opts.delete(:wait)
      wait = true if wait.nil?

      # Create the action:
      action = Action.new(opts)

      # The constructor of the action doesn't remove the options that it uses, so we need to remove them explicitly
      # before checking for bad options.
      specs.each_entry do |key, _|
        opts.delete(key)
      end
      check_bad_opts(specs, opts)

      # Create and send the request:
      request = HttpRequest.new
      request.method = :POST
      request.url = "#{absolute_path}/#{name}"
      request.headers = headers
      request.query = query
      request.body = Writer.write(action, indent: true)
      request.timeout = timeout
      connection.send(request)
      result = Future.new(self, request) do |response|
        raise response if response.is_a?(Exception)

        case response.code
        when 200, 201, 202
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
      connection.raise_error(response, 'The response body is empty') if response.body.nil? || response.body.length.zero?

      # Check the content type, as otherwise the parsing will fail, and the resulting error message won't be explicit
      # about the cause of the problem:
      connection.check_xml_content_type(response)

      # Parse the XML and generate the SDK object:
      Reader.read(response.body)
    end

    #
    # Returns the absolute path of this service.
    #
    # @return [String] The absolute path of this service. For example, the path of the `vm` service that manages
    #   virtual machine `123` will be `vms/123`. Note that this absolute path doesn't include the `/ovirt-engine/api/'
    #   prefix.
    #
    # @api private
    #
    def absolute_path
      return @path if @parent.is_a? Connection

      prefix = @parent.absolute_path
      return @path if prefix.empty?

      "#{prefix}/#{@path}"
    end

    private

    #
    # Checks if the given hash contains any value, and if it does raises an exception indicating that they are not
    # supported.
    #
    # @param specs [Array<Array<Symbol, Class>>] An array of tuples containing the names and types of the parameters.
    # @param opts [Hash] The hash containing the values of the parameters.
    #
    def check_bad_opts(specs, opts)
      return if opts.empty?

      bad_names = opts.keys
      bad_text = nice_list(bad_names)
      if bad_names.length > 1
        message = "The options #{bad_text} aren't supported."
      else
        message = "The option #{bad_text} isn't supported."
      end
      good_names = specs.map(&:first)
      unless good_names.empty?
        good_text = nice_list(good_names)
        if good_names.length > 1
          message << " The supported options are #{good_text}."
        else
          message << " The only supported option is #{good_text}."
        end
      end
      raise Error, message
    end

    #
    # Generates a human readable list containing the names of the given symbols.
    #
    # @param items [Array<Symbol>]
    # @return [String] An string containing the names of the symbols, sorted, quoted, and in a gramatically correct
    #   format.
    #
    def nice_list(items)
      return nil if items.empty?

      items = items.sort
      items = items.map { |item| "'#{item}'" }
      return items.first if items.length == 1

      head = items[0, items.length - 1].join(', ')
      tail = items.last
      "#{head} and #{tail}"
    end
  end
end
