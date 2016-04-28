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
      return reader.read_element
    end

    #
    # Reads a list of string values, assuming that the cursor is positioned at the start of the element that contains
    # the first value.
    #
    # @param reader [XmlReader]
    # @return [Array<String>]
    #
    def self.read_strings(reader)
      return reader.read_elements
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
        raise Error.new("The text '#{text}' isn't a valid boolean value.")
      end
    end

    #
    # Reads a boolean value, assuming that the cursor is positioned at the start element that contains the value.
    #
    # @param reader [XmlReader]
    # @return [Boolean]
    #
    def self.read_boolean(reader)
      return Reader.parse_boolean(reader.read_element)
    end

    #
    # Reads a list of boolean values, assuming that the cursor is positioned at the start element that contains
    # the values.
    #
    # @param reader [XmlReader]
    # @return [Array<Boolean>]
    #
    def self.read_booleans(reader)
      return reader.read_elements.map { |text| Reader.parse_boolean(text) }
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
      rescue
        raise Error.new("The text '#{text}' isn't a valid integer value.")
      end
    end

    #
    # Reads an integer value, assuming that the cursor is positioned at the start element that contains the value.
    #
    # @param reader [XmlReader]
    # @return [Integer]
    #
    def self.read_integer(reader)
      return Reader.parse_integer(reader.read_element)
    end

    #
    # Reads a list of integer values, assuming that the cursor is positioned at the start element that contains the
    # values.
    #
    # @param reader [XmlReader]
    # @return [Array<Integer>]
    #
    def self.read_integers(reader)
      return reader.read_elements.map { |text| Reader.parse_integer(text) }
    end

    #
    # Converts the given text to a decimal value.
    #
    # @return [Fixnum]
    #
    def self.parse_decimal(text)
      return nil if text.nil?
      begin
        return Float(text)
      rescue
        raise Error.new("The text '#{text}' isn't a valid decimal value.")
      end
    end

    #
    # Reads a decimal value, assuming that the cursor is positioned at the start element that contains the value.
    #
    # @param reader [XmlReader]
    # @return [Fixnum]
    #
    def self.read_decimal(reader)
      return Reader.parse_decimal(reader.read_element)
    end

    #
    # Reads a list of decimal values, assuming that the cursor is positioned at the start element that contains the
    # values.
    #
    # @param reader [XmlReader]
    # @return [Array<Fixnum>]
    #
    def self.read_decimals(reader)
      return reader.read_elements.map { |text| Reader.parse_decimal(text) }
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
      rescue
        raise Error.new("The text '#{text}' isn't a valid date.")
      end
    end

    #
    # Reads a date value, assuming that the cursor is positioned at the start element that contains the value.
    #
    # @param reader [XmlReader]
    # @return [DateTime]
    #
    def self.read_date(reader)
      return Reader.parse_date(reader.read_element)
    end

    #
    # Reads a list of dates values, assuming that the cursor is positioned at the start element that contains the
    # values.
    #
    # @param reader [XmlReader]
    # @return [Array<DateTime>]
    #
    def self.read_dates(reader)
      return reader.read_elements.map { |text| Reader.parse_date(text) }
    end

  end

end
