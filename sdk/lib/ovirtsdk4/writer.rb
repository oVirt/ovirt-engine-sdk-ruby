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
      if value
        return 'true'
      else
        return 'false'
      end
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
      return value.to_s
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
    # @param value [Fixnum]
    # @return [String]
    #
    def self.render_decimal(value)
      return value.to_s
    end

    #
    # Writes an element with the given name and decimal value.
    #
    # @param writer [XmlWriter]
    # @param name [String]
    # @param value [Fixnum]
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
      return value.xmlschema
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

  end

end
