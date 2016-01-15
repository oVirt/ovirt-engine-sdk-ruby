#--
# Copyright (c) 2015 Red Hat, Inc.
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

module Ovirt
  module SDK
    module V4

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
  end
end
