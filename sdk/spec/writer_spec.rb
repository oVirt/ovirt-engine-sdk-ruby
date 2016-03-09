#
# Copyright (c) 2016 Red Hat, Inc.
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

describe SDK::Writer do

  describe ".render_boolean" do

    context "given false" do

      it "returns 'false'" do
        result = SDK::Writer.render_boolean(false)
        expect(result).to eql('false')
      end

    end

    context "given true" do

      it "returns 'true'" do
        result = SDK::Writer.render_boolean(true)
        expect(result).to eql('true')
      end

    end

    context "given nil" do

      it "returns 'false'" do
        result = SDK::Writer.render_boolean(nil)
      end

    end

  end
  describe ".write_string" do

    context "given name and value" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_string(writer, 'value', 'myvalue')
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
        SDK::Writer.write_boolean(writer, 'value', true)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>true</value>')
      end

    end

    context "given name and false" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_boolean(writer, 'value', false)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>false</value>')
      end

    end

    context "given name and truthy" do

      it "writes 'true'" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_boolean(writer, 'value', 'myvalue')
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>true</value>')
      end

    end

    context "given name and falsy" do

      it "writes 'false'" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_boolean(writer, 'value', nil)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>false</value>')
      end

    end

  end

  describe ".render_integer" do

    context "given zero" do

      it "writes the expected string" do
        expect(SDK::Writer.render_integer(0)).to eql('0')
      end

    end

    context "given one" do

      it "writes the expected string" do
        expect(SDK::Writer.render_integer(1)).to eql('1')
      end

    end

    context "given minus one" do

      it "writes the expected string" do
        expect(SDK::Writer.render_integer(-1)).to eql('-1')
      end

    end

  end

  describe ".write_integer" do

    context "given zero" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_integer(writer, 'value', 0)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>0</value>')
      end

    end

    context "given one" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_integer(writer, 'value', 1)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>1</value>')
      end

    end

    context "given minus one" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_integer(writer, 'value', -1)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>-1</value>')
      end

    end

  end

  describe ".render_decimal" do

    context "given zero" do

      it "writes the expected string" do
        expect(SDK::Writer.render_integer(0.0)).to eql('0.0')
      end

    end

    context "given one" do

      it "writes the expected string" do
        expect(SDK::Writer.render_integer(1.0)).to eql('1.0')
      end

    end

    context "given minus one" do

      it "writes the expected string" do
        expect(SDK::Writer.render_integer(-1.0)).to eql('-1.0')
      end

    end

    context "given pi" do

      it "writes the expected string" do
        expect(SDK::Writer.render_integer(3.1415)).to eql('3.1415')
      end

    end

  end

  describe ".write_decimal" do

    context "given zero" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_integer(writer, 'value', 0.0)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>0.0</value>')
      end

    end

    context "given one" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_integer(writer, 'value', 1.0)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>1.0</value>')
      end

    end

    context "given minus one" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_integer(writer, 'value', -1.0)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>-1.0</value>')
      end

    end

    context "given pi" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::Writer.write_integer(writer, 'value', 3.1415)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>3.1415</value>')
      end

    end

  end

  describe ".render_date" do

    context "given a date" do

      it "writes the expected string" do
        date = DateTime.new(2015, 12, 10, 22, 00, 30, '+1')
        expect(SDK::Writer.render_integer(date)).to eql('2015-12-10T22:00:30+01:00')
      end

    end

  end

  describe ".write_date" do

    context "given a date" do

      it "writes the expected XML" do
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        date = DateTime.new(2015, 12, 10, 22, 00, 30, '+1')
        SDK::Writer.write_date(writer, 'value', date)
        writer.flush
        result = writer.io.string
        expect(result).to eql('<value>2015-12-10T22:00:30+01:00</value>')
      end

    end

  end

end
