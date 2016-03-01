#--
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
#++

require 'date'

module OvirtSDK4

  ##
  # This is an utility class used to format objects for use in HTTP requests. It is inteded for use by other
  # components of the SDK. Refrain from using it directly, as backwards compatibility isn't guaranteed.
  #
  class XmlFormatter

    ##
    # Formats a boolean value.
    #
    def self.format_boolean(value)
      if value
        return 'true'
      else
        return 'false'
      end
    end

  end

  ##
  # This is an utility class used to read XML documents using an streaming approach. It is inteded for use by
  # other components of the SDK. Refrain from using it directly, as backwards compatibility isn't guaranteed.
  #
  # The part of the code that requires calls to _libxml_ is written in C, as an extension.
  #
  class XmlReader

    ##
    # Jumps to the next start tag, end tag or end of document. Returns `true` if stopped at an start tag, `false`
    # otherwise.
    #
    def forward
      loop do
        case node_type
        when XmlConstants::TYPE_ELEMENT
          return true
        when XmlConstants::TYPE_END_ELEMENT, XmlConstants::TYPE_NONE
          return false
        else
          read
        end
      end
    end

    ##
    # Reads a string value, assuming that the cursor is positioned at the start element that contains the value.
    #
    def read_string
      return read_element
    end

    ##
    # Reads a boolean value, assuming that the cursor is positioned at the start element that contains the value.
    #
    def read_boolean
      image = read_element
      begin
        case image.downcase
        when 'false', '0'
          return false
        when 'true', '1'
          return true
        else
          raise Error.new("The text \"#{image}\" isn't a valid boolean value.")
        end
      ensure
        next_element
      end
    end

    ##
    # Reads a list of boolean values, assuming that the cursor is positioned at the start element that contains
    # the values.
    #
    def read_booleans
      list = []
      loop do
        case node_type
        when XmlConstants::TYPE_ELEMENT
          list << read_boolean
        when XmlConstants::TYPE_END_ELEMENT, XmlConstants::TYPE_NONE
          break
        end
      end
      return list
    end

    ##
    # Reads an integer value, assuming that the cursor is positioned at the start element that contains the value.
    #
    def read_integer
      image = read_element
      begin
        return Integer(image, 10)
      rescue
        raise Error.new("The text \"#{image}\" isn't a valid integer value.")
      ensure
        next_element
      end
    end

    ##
    # Reads a list of integer values, assuming that the cursor is positioned at the start element that contains the
    # values.
    #
    def read_integers
      list = []
      loop do
        case node_type
        when XmlConstants::TYPE_ELEMENT
          list << read_integer
        when XmlConstants::TYPE_END_ELEMENT, XmlConstants::TYPE_NONE
          break
        end
      end
      return list
    end

    ##
    # Reads a decimal value, assuming that the cursor is positioned at the start element that contains the value.
    #
    def read_decimal
      image = read_element
      begin
        return Float(image)
      rescue
        raise Error.new("The text \"#{image}\" isn't a valid decimal value.")
      ensure
        next_element
      end
    end

    ##
    # Reads a list of decimal values, assuming that the cursor is positioned at the start element that contains the
    # values.
    #
    def read_decimals
      list = []
      loop do
        case node_type
        when XmlConstants::TYPE_ELEMENT
          list << read_decimal
        when XmlConstants::TYPE_END_ELEMENT, XmlConstants::TYPE_NONE
          break
        end
      end
      return list
    end

    ##
    # Reads a date value, assuming that the cursor is positioned at the start element # that contains the value.
    #
    def read_date
      image = read_element
      begin
        return DateTime.xmlschema(image)
      rescue
        raise Error.new("The text \"#{image}\" isn't a valid date.")
      ensure
        next_element
      end
    end

    ##
    # Reads a list of dates values, assuming that the cursor is positioned at the start element that contains the
    # values.
    #
    def read_dates
      list = []
      loop do
        case node_type
        when XmlConstants::TYPE_ELEMENT
          list << read_date
        when XmlConstants::TYPE_END_ELEMENT, XmlConstants::TYPE_NONE
          break
        end
      end
      return list
    end

  end

  ##
  # This is an utility class used to generate XML documents using an streaming approach. It is inteded for use by
  # other components of the SDK. Refrain from using it directly, as backwards compatibility isn't guaranteed.
  #
  # The part of the code that requires calls to _libxml_ is written in C, as an extension.
  #
  class XmlWriter

    ##
    # Writes an string value.
    #
    def write_string(name, value)
      write_element(name, value)
    end

    ##
    # Writes a boolean value.
    #
    def write_boolean(name, value)
      if value
        write_element(name, 'true')
      else
        write_element(name, 'false')
      end
    end

    ##
    # Writes an integer value.
    #
    def write_integer(name, value)
      write_element(name, value.to_s)
    end

  end

end
