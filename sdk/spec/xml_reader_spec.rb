#
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

  describe ".read_boolean" do

    context "given 'false'" do
      it "returns false" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>false</value>')
        })
        expect(reader.read_boolean).to be false
      end
    end

    context "given 'FALSE'" do
      it "returns false ignoring case" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>FALSE</value>')
        })
        expect(reader.read_boolean).to be false
      end
    end

    context "given '0'" do
      it "returns false" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>0</value>')
        })
        expect(reader.read_boolean).to be false
      end
    end

    context "given 'true'" do
      it "returns true" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>true</value>')
        })
        expect(reader.read_boolean).to be true
      end
    end

    context "given 'TRUE'" do
      it "returns true ignoring case" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>TRUE</value>')
        })
        expect(reader.read_boolean).to be true
      end
    end

    context "given '1'" do
      it "returns true" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>1</value>')
        })
        expect(reader.read_boolean).to be true
      end
    end

    context "given a valid value" do
      it "moves to the next element" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root><value>true</value><next/></root>')
        })
        reader.read
        reader.read_boolean
        expect(reader.node_name).to eql('next')
      end
    end

    context "given an invalid value" do
      it "raises an error" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>ugly</value>')
        })
        expect { reader.read_boolean }.to raise_error(SDK::Error, /ugly/)
      end
    end

    context "given an invalid value" do
      it "moves to the next element" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root><value>ugly</value><next/></root>')
        })
        reader.read
        begin
          reader.read_boolean
        rescue
        end
        expect(reader.node_name).to eql("next")
      end
    end

  end

  describe ".read_booleans" do

    context "given no values with close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list></list>')
        })
        reader.read
        expect(reader.read_booleans).to eql([])
      end
    end

    context "given no values without close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list/>')
        })
        reader.read
        expect(reader.read_booleans).to eql([])
      end
    end

    context "given one value" do
      it "returns a list containing the value" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><value>false</value></list>')
        })
        reader.read
        expect(reader.read_booleans).to eql([false])
      end
    end

    context "given two values" do
      it "returns a list containing the two values" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><value>false</value><value>true</value></list>')
        })
        reader.read
        expect(reader.read_booleans).to eql([false, true])
      end
    end

  end

  describe ".read_integer" do

    context "given a valid value" do

      it "returns that value" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>0</value>')
        })
        expect(reader.read_integer).to eql(0)
      end

      it "moves to the next element" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root><value>0</value><next/></root>')
        })
        reader.read
        reader.read_integer
        expect(reader.node_name).to eql('next')
      end

    end

    context "given an invalid value" do

      it "raises an error" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>ugly</value>')
        })
        expect { reader.read_integer }.to raise_error(SDK::Error, /ugly/)
      end

      it "moves to the next element" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root><value>ugly</value><next/></root>')
        })
        reader.read
        begin
          reader.read_integer
        rescue
        end
        expect(reader.node_name).to eql("next")
      end

    end

  end

  describe ".read_integers" do

    context "given no values with close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list></list>')
        })
        reader.read
        expect(reader.read_integers).to eql([])
      end
    end

    context "given no values without close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list/>')
        })
        reader.read
        expect(reader.read_integers).to eql([])
      end
    end

    context "given one value" do
      it "returns a list containing the value" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><value>0</value></list>')
        })
        reader.read
        expect(reader.read_integers).to eql([0])
      end
    end

    context "given two values" do
      it "returns a list containing the two values" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><value>0</value><value>1</value></list>')
        })
        reader.read
        expect(reader.read_integers).to eql([0, 1])
      end
    end

  end

  describe ".read_decimal" do

    context "given a valid value" do

      it "returns that value" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>1.0</value>')
        })
        expect(reader.read_decimal).to eql(1.0)
      end

      it "moves to the next element" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root><value>0</value><next/></root>')
        })
        reader.read
        reader.read_decimal
        expect(reader.node_name).to eql("next")
      end

    end

    context "given an invalid value" do

      it "raises an error" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>ugly</value>')
        })
        expect { reader.read_decimal }.to raise_error(SDK::Error, /ugly/)
      end

      it "moves to the next element" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root><value>ugly</value><next/></root>')
        })
        reader.read
        begin
          reader.read_decimal
        rescue
        end
        expect(reader.node_name).to eql("next")
      end

    end

  end

  describe ".read_decimals" do

    context "given no values with close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list></list>')
        })
        reader.read
        expect(reader.read_decimals).to eql([])
      end
    end

    context "given no values without close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list/>')
        })
        reader.read
        expect(reader.read_decimals).to eql([])
      end
    end

    context "given one value" do
      it "returns a list containing the value" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><value>1.1</value></list>')
        })
        reader.read
        expect(reader.read_decimals).to eql([1.1])
      end
    end

    context "given two values" do
      it "returns a list containing the two values" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list><value>1.1</value><value>2.2</value></list>')
        })
        reader.read
        expect(reader.read_decimals).to eql([1.1, 2.2])
      end
    end

  end

  describe ".read_date" do

    context "given a valid date" do

      it "returns that date" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>2015-12-10T22:00:30+01:00</value>')
        })
        date = DateTime.new(2015, 12, 10, 22, 00, 30, '+1')
        expect(reader.read_date).to eql(date)
      end

      it "moves to the next element" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root><value>2015-12-10T22:00:30+01:00</value><next/></root>')
        })
        reader.read
        reader.read_date
        expect(reader.node_name).to eql("next")
      end

    end

    context "given an invalid value" do

      it "raises an error" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<value>ugly</value>')
        })
        expect { reader.read_date }.to raise_error(SDK::Error, /ugly/)
      end

      it "moves to the next element" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<root><value>ugly</value><next/></root>')
        })
        reader.read
        begin
          reader.read_date
        rescue
        end
        expect(reader.node_name).to eql("next")
      end

    end

  end

  describe ".read_dates" do

    context "given no values with close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list></list>')
        })
        reader.read
        expect(reader.read_dates).to eql([])
      end
    end

    context "given no values without close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new('<list/>')
        })
        reader.read
        expect(reader.read_dates).to eql([])
      end
    end

    context "given one value" do
      it "returns a list containing the value" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new(
            '<list>' +
            '<value>2015-12-10T22:00:30+01:00</value>' +
            '</list>'
          )
        })
        reader.read
        dates = [
          DateTime.new(2015, 12, 10, 22, 00, 30, '+1'),
        ]
        expect(reader.read_dates).to eql(dates)
      end
    end

    context "given two values" do
      it "returns a list containing the two values" do
        reader = SDK::XmlReader.new({
          :io => StringIO.new(
            '<list>' +
            '<value>2015-12-10T22:00:30+01:00</value>' +
            '<value>2016-12-10T22:00:30+01:00</value>' +
            '</list>'
          )
        })
        reader.read
        dates = [
          DateTime.new(2015, 12, 10, 22, 00, 30, '+1'),
          DateTime.new(2016, 12, 10, 22, 00, 30, '+1'),
        ]
        expect(reader.read_dates).to eql(dates)
      end
    end

  end

end
