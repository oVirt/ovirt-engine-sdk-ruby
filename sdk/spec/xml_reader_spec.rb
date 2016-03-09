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

require 'spec_helper'

describe SDK::XmlReader do

  describe ".read_attribute" do

    context "given attribute with value" do

      it "returns the value" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root id="123"/>')
        })
        expect(reader.node_name).to eql('root')
        expect(reader.get_attribute('id')).to eql('123')
      end

    end

    context "given empty attribute" do

      it "returns empty string" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root id=""/>')
        })
        expect(reader.get_attribute('id')).to eql('')
      end

    end

    context "given non existent attribute" do

      it "returns nil" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root/>')
        })
        expect(reader.get_attribute('id')).to be(nil)
      end

    end

  end

  describe ".read_element" do

    context "given an empty element" do

      it "returns nil" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root/>')
        })
        expect(reader.read_element).to be(nil)
      end

    end

    context "given blank element" do

      it "returns empty string" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root></root>')
        })
        expect(reader.read_element).to eql('')
      end

    end

  end

  describe ".read_elements" do

    context "given an empty element" do

      it "returns nil" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list></list>')
        })
        reader.read
        expect(reader.read_elements).to eql([])
      end

    end

    context "given an a list with an empty element" do

      it "returns a list containing nil" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><item/></list>')
        })
        reader.read
        expect(reader.read_elements).to eql([nil])
      end

    end

    context "given an a list with a blank element" do

      it "returns a list containing an empty string" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><item></item></list>')
        })
        reader.read
        expect(reader.read_elements).to eql([''])
      end

    end

    context "given an a list with one element" do

      it "returns a list containing it" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><item>first</item></list>')
        })
        reader.read
        expect(reader.read_elements).to eql(['first'])
      end

    end

    context "given an a list with two elements" do

      it "returns a list containing them" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><item>first</item><item>second</item></list>')
        })
        reader.read
        expect(reader.read_elements).to eql(['first', 'second'])
      end

    end

  end

  describe ".forward" do

    context "given preceding text" do

      it "skips it and returns true" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root>text<target/></root>')
        })
        reader.read
        expect(reader.forward).to be true
        expect(reader.node_name).to eql('target')
      end

    end

    context "given end of document" do

      it "returns false" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root/>')
        })
        reader.read
        expect(reader.forward).to be false
      end

    end

    context "given an empty element" do

      it "returns true and stays in the empty element" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root><target/></root>')
        })
        reader.read
        expect(reader.forward).to be true
        expect(reader.node_name).to eql('target')
        expect(reader.empty_element?).to be true
      end

    end

  end

end
