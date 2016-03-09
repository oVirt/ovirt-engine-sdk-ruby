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

require 'spec_helper'

describe SDK::XmlWriter do

  describe ".io" do

    context "created with an IO object" do

      it "returns the original IO object" do
          io = StringIO.new
          writer = SDK::XmlWriter.new({:io => io})
          expect(writer.io).to equal(io)

      end

    end

  end

  describe ".write_element" do

    context "given name and value" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        writer.write_element('value', 'myvalue')
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>myvalue</value>')
      end

    end

  end

end
