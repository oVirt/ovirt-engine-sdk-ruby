#
# Copyright (c) 2015 Red Hat, Inc.
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
  # This is the base class for all the XML readers used by the SDK. It contains the utility methods used by all
  # of them.
  #
  # @api private
  #
  class Reader
    #
    # Reads a string value, assuming that the cursor is positioned at the start element that contains the value.
    #
    # @param reader [XmlReader]
    # @return [String]
    #
    def self.read_string(reader)
      reader.read_element
    end

    #
    # Reads a list of string values, assuming that the cursor is positioned at the start of the element that contains
    # the first value.
    #
    # @param reader [XmlReader]
    # @return [Array<String>]
    #
    def self.read_strings(reader)
      reader.read_elements
    end

    #
    # Converts the given text to a boolean value.
    #
    # @param text [String]
    # @return [Boolean]
    #
    def self.parse_boolean(text)
      return nil if text.nil?
      case text.downcase
      when 'false', '0'
        return false
      when 'true', '1'
        return true
      else
        raise Error, "The text '#{text}' isn't a valid boolean value."
      end
    end

    #
    # Reads a boolean value, assuming that the cursor is positioned at the start element that contains the value.
    #
    # @param reader [XmlReader]
    # @return [Boolean]
    #
    def self.read_boolean(reader)
      Reader.parse_boolean(reader.read_element)
    end

    #
    # Reads a list of boolean values, assuming that the cursor is positioned at the start element that contains
    # the values.
    #
    # @param reader [XmlReader]
    # @return [Array<Boolean>]
    #
    def self.read_booleans(reader)
      reader.read_elements.map { |text| Reader.parse_boolean(text) }
    end

    #
    # Converts the given text to an integer value.
    #
    # @param text [String]
    # @return [Integer]
    #
    def self.parse_integer(text)
      return nil if text.nil?
      begin
        return Integer(text, 10)
      rescue ArgumentError
        raise Error, "The text '#{text}' isn't a valid integer value."
      end
    end

    #
    # Reads an integer value, assuming that the cursor is positioned at the start element that contains the value.
    #
    # @param reader [XmlReader]
    # @return [Integer]
    #
    def self.read_integer(reader)
      Reader.parse_integer(reader.read_element)
    end

    #
    # Reads a list of integer values, assuming that the cursor is positioned at the start element that contains the
    # values.
    #
    # @param reader [XmlReader]
    # @return [Array<Integer>]
    #
    def self.read_integers(reader)
      reader.read_elements.map { |text| Reader.parse_integer(text) }
    end

    #
    # Converts the given text to a decimal value.
    #
    # @return [Float]
    #
    def self.parse_decimal(text)
      return nil if text.nil?
      begin
        return Float(text)
      rescue ArgumentError
        raise Error, "The text '#{text}' isn't a valid decimal value."
      end
    end

    #
    # Reads a decimal value, assuming that the cursor is positioned at the start element that contains the value.
    #
    # @param reader [XmlReader]
    # @return [Float]
    #
    def self.read_decimal(reader)
      Reader.parse_decimal(reader.read_element)
    end

    #
    # Reads a list of decimal values, assuming that the cursor is positioned at the start element that contains the
    # values.
    #
    # @param reader [XmlReader]
    # @return [Array<Float>]
    #
    def self.read_decimals(reader)
      reader.read_elements.map { |text| Reader.parse_decimal(text) }
    end

    #
    # Converts the given text to a date value.
    #
    # @param text [String]
    # @return [DateTime]
    #
    def self.parse_date(text)
      return nil if text.nil?
      begin
        return DateTime.xmlschema(text)
      rescue ArgumentError
        raise Error, "The text '#{text}' isn't a valid date."
      end
    end

    #
    # Reads a date value, assuming that the cursor is positioned at the start element that contains the value.
    #
    # @param reader [XmlReader]
    # @return [DateTime]
    #
    def self.read_date(reader)
      Reader.parse_date(reader.read_element)
    end

    #
    # Reads a list of dates values, assuming that the cursor is positioned at the start element that contains the
    # values.
    #
    # @param reader [XmlReader]
    # @return [Array<DateTime>]
    #
    def self.read_dates(reader)
      reader.read_elements.map { |text| Reader.parse_date(text) }
    end

    #
    # Converts the given text to an enum.
    #
    # @param enum_module [Module]
    # @param text [String]
    # @return [String]
    #
    def self.parse_enum(enum_module, text)
      return nil unless text
      values = enum_module.constants.map { |const| enum_module.const_get(const) }
      values.detect { |value| value.casecmp(text).zero? }
    end

    #
    # Reads a enum value, assuming that the cursor is positioned at the
    # start element that contains the value.
    #
    # @param enum_module [Module]
    # @param reader [XmlReader]
    # @return [Array<String>]
    #
    def self.read_enum(enum_module, reader)
      Reader.parse_enum(enum_module, reader.read_element)
    end

    #
    # Reads a list of enum values, assuming that the cursor is positioned
    # at the start element of the element that contains the first value.
    #
    # @param enum_module [Module]
    # @param reader [XmlReader]
    # @return [Array<String>]
    #
    def self.read_enums(enum_module, reader)
      reader.read_elements.map { |text| Reader.parse_enum(enum_module, text) }
    end

    #
    # This hash stores for each known tag a reference to the method that read the object corresponding for that tag. For
    # example, for the `vm` tag it will contain a reference to the `VmReader.read_one` method, and for the `vms` tag
    # it will contain a reference to the `VmReader.read_many` method.
    #
    @readers = {}

    #
    # Registers a read method.
    #
    # @param tag [String] The tag name.
    # @param reader [Method] The reference to the method that reads the object corresponding to the `tag`.
    #
    def self.register(tag, reader)
      @readers[tag] = reader
    end

    #
    # Reads one object, determining the reader method to use based on the tag name of the first element. For example,
    # if the first tag name is `vm` then it will create a `Vm` object, if it the tag is `vms` it will create an array
    # of `Vm` objects, so on.
    #
    # @param source [String, XmlReader] The string, IO or XML reader where the input will be taken from.
    #
    def self.read(source)
      # If the source is a string or IO object then create a XML reader from it:
      cursor = nil
      if source.is_a?(String) || source.is_a?(IO)
        cursor = XmlReader.new(source)
      elsif source.is_a?(XmlReader)
        cursor = source
      else
        raise ArgumentError, "Expected a 'String' or 'XmlReader', but got '#{source.class}'"
      end

      # Do the actual read, and make sure to always close the XML reader if we created it:
      begin
        # Do nothing if there aren't more tags:
        return nil unless cursor.forward

        # Select the specific reader according to the tag:
        tag = cursor.node_name
        reader = @readers[tag]
        raise Error, "Can't find a reader for tag '#{tag}'" if reader.nil?

        # Read the object using the specific reader:
        reader.call(cursor)
      ensure
        cursor.close if !cursor.nil? && !cursor.equal?(source)
      end
    end
  end
end
