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
  # This is the base class for all the XML writers used by the SDK. It contains the utility methods used by
  # all of them.
  #
  # @api private
  #
  class Writer
    #
    # Writes an element with the given name and string value.
    #
    # @param writer [XmlWriter]
    # @param name [String]
    # @param text [String]
    #
    def self.write_string(writer, name, value)
      writer.write_element(name, value)
    end

    #
    # Converts the given boolean value to an string.
    #
    # @param value [Boolean]
    # @return [String]
    #
    def self.render_boolean(value)
      value ? 'true' : 'false'
    end

    #
    # Writes an element with the given name and boolean value.
    #
    # @param writer [XmlWriter]
    # @param name [String]
    # @param value [Boolean]
    #
    def self.write_boolean(writer, name, value)
      writer.write_element(name, Writer.render_boolean(value))
    end

    #
    # Converts the given integer value to an string.
    #
    # @param value [Integer]
    # @return [String]
    #
    def self.render_integer(value)
      value.to_s
    end

    #
    # Writes an element with the given name and integer value.
    #
    # @param writer [XmlWriter]
    # @param name [String]
    # @param value [Integer]
    #
    def self.write_integer(writer, name, value)
      writer.write_element(name, Writer.render_integer(value))
    end

    #
    # Converts the given decimal value to an string.
    #
    # @param value [Float]
    # @return [String]
    #
    def self.render_decimal(value)
      value.to_s
    end

    #
    # Writes an element with the given name and decimal value.
    #
    # @param writer [XmlWriter]
    # @param name [String]
    # @param value [Float]
    #
    def self.write_decimal(writer, name, value)
      writer.write_element(name, Writer.render_decimal(value))
    end

    #
    # Converts the given date value to an string.
    #
    # @param value [DateTime]
    # @return [String]
    #
    def self.render_date(value)
      value.xmlschema
    end

    #
    # Converts the given value to an string, assuming that it is of the given type.
    #
    # @param value [Object] The value.
    # @param type [Class] The type.
    # @return [String] The string that represents the value.
    #
    def self.render(value, type)
      if type.equal?(String)
        value
      elsif type.equal?(TrueClass)
        render_boolean(value)
      elsif type.equal?(Integer)
        render_integer(value)
      elsif type.equal?(Float)
        render_decimal(value)
      elsif type.equal?(DateTime)
        render_date(value)
      else
        raise Error, "Don't know how to render value '#{value}' of type '#{type}'"
      end
    end

    #
    # Writes an element with the given name and date value.
    #
    # @param writer [XmlWriter]
    # @param name [String]
    # @param value [DateTime]
    #
    def self.write_date(writer, name, value)
      writer.write_element(name, Writer.render_date(value))
    end

    #
    # This hash stores for each known type a reference to the method that writes the XML document corresponding for that
    # type. For example, for the `Vm` type it will contain a reference to the `VmWriter.write_one` method.
    #
    @writers = {}

    #
    # Registers a write method.
    #
    # @param type [Class] The type.
    # @param writer [Method] The reference to the method that writes the XML document corresponding to the type.
    #
    def self.register(type, writer)
      @writers[type] = writer
    end

    #
    # Writes one object, determining the writer method to use based on the type. For example if the type of the object
    # is `Vm` then it will create write the `vm` tag, with its contents.
    #
    # @param object [Struct] The object to write.
    #
    # @param opts [Hash] Options to alter the behaviour of the method.
    #
    # @option opts [XmlWriter] :target The XML writer where the output will be written. If it this option
    #   isn't given, or if the value is `nil` the method will return a string contain the XML document.
    #
    # @option opts [String] :root The name of the root tag of the generated XML document. This isn't needed
    #   when writing single objects, as the tag is calculated from the type of the object, for example, if
    #   the object is a virtual machine then the tag will be `vm`. But when writing arrays of objects the tag
    #   is needed, because the list may be empty, or have different types of objects. In this case, for arrays,
    #   if the name isn't provided an exception will be raised.
    #
    # @option opts [Boolean] :indent (false) Indicates if the output should be indented, for easier reading by humans.
    #
    def self.write(object, opts = {})
      # Get the options:
      target = opts[:target]
      root = opts[:root]
      indent = opts[:indent] || false

      # If the target is `nil` then create a temporary XML writer to write the output:
      cursor = nil
      if target.nil?
        cursor = XmlWriter.new(nil, indent)
      elsif target.is_a?(XmlWriter)
        cursor = target
      else
        raise ArgumentError, "Expected an 'XmlWriter', but got '#{target.class}'"
      end

      # Do the actual write, and make sure to always close the XML writer if we created it:
      begin
        if object.is_a?(Array)
          # For arrays we can't decide which tag to use, so the 'root' parameter is mandatory in this case:
          raise Error, "The 'root' option is mandatory when writing arrays" if root.nil?

          # Write the root tag, and then recursively call the method to write each of the items of the array:
          cursor.write_start(root)
          object.each do |item|
            write(item, target: cursor)
          end
          cursor.write_end
        else
          # Select the specific writer according to the type:
          type = object.class
          writer = @writers[type]
          raise Error, "Can't find a writer for type '#{type}'" if writer.nil?

          # Write the object using the specific method:
          writer.call(object, cursor, root)
        end

        # If no XML cursor was explicitly given, and we created it, then we need to return the generated XML text:
        cursor.string if target.nil?
      ensure
        cursor.close if !cursor.nil? && !cursor.equal?(target)
      end
    end
  end
end
