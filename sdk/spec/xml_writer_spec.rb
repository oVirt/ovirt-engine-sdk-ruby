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

  describe ".write_string" do

    context "given name and value" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        writer.write_string('value', 'myvalue')
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>myvalue</value>')
      end

    end

  end

  describe ".write_boolean" do

    context "given name and true" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        writer.write_boolean('value', true)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>true</value>')
      end

    end

    context "given name and false" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        writer.write_boolean('value', false)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>false</value>')
      end

    end

    context "given name and truthy" do

      it "writes 'true'" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        writer.write_boolean('value', 'myvalue')
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>true</value>')
      end

    end

    context "given name and falsy" do

      it "writes 'false'" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        writer.write_boolean('value', nil)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>false</value>')
      end

    end

  end

  describe ".write_integer" do

    context "given zero" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        writer.write_integer('value', 0)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>0</value>')
      end

    end

    context "given one" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        writer.write_integer('value', 1)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>1</value>')
      end

    end

  end

end
