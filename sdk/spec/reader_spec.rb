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

describe SDK::Reader do

  describe ".read_boolean" do

    context "given 'false'" do
      it "returns false" do
        reader = SDK::XmlReader.new('<value>false</value>')
        expect(SDK::Reader.read_boolean(reader)).to be false
      end
    end

    context "given 'FALSE'" do
      it "returns false ignoring case" do
        reader = SDK::XmlReader.new('<value>FALSE</value>')
        expect(SDK::Reader.read_boolean(reader)).to be false
      end
    end

    context "given '0'" do
      it "returns false" do
        reader = SDK::XmlReader.new('<value>0</value>')
        expect(SDK::Reader.read_boolean(reader)).to be false
      end
    end

    context "given 'true'" do
      it "returns true" do
        reader = SDK::XmlReader.new('<value>true</value>')
        expect(SDK::Reader.read_boolean(reader)).to be true
      end
    end

    context "given 'TRUE'" do
      it "returns true ignoring case" do
        reader = SDK::XmlReader.new('<value>TRUE</value>')
        expect(SDK::Reader.read_boolean(reader)).to be true
      end
    end

    context "given '1'" do
      it "returns true" do
        reader = SDK::XmlReader.new('<value>1</value>')
        expect(SDK::Reader.read_boolean(reader)).to be true
      end
    end

    context "given an invalid value" do
      it "raises an error" do
        reader = SDK::XmlReader.new('<value>ugly</value>')
        expect { SDK::Reader.read_boolean(reader) }.to raise_error(SDK::Error, /ugly/)
      end
    end

  end

  describe ".read_booleans" do

    context "given no values with close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new('<list></list>')
        reader.read
        expect(SDK::Reader.read_booleans(reader)).to eql([])
      end
    end

    context "given no values without close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new('<list/>')
        reader.read
        expect(SDK::Reader.read_booleans(reader)).to eql([])
      end
    end

    context "given one value" do
      it "returns a list containing the value" do
        reader = SDK::XmlReader.new('<list><value>false</value></list>')
        reader.read
        expect(SDK::Reader.read_booleans(reader)).to eql([false])
      end
    end

    context "given two values" do
      it "returns a list containing the two values" do
        reader = SDK::XmlReader.new('<list><value>false</value><value>true</value></list>')
        reader.read
        expect(SDK::Reader.read_booleans(reader)).to eql([false, true])
      end
    end

  end

  describe ".read_integer" do

    context "given a valid value" do

      it "returns that value" do
        reader = SDK::XmlReader.new('<value>0</value>')
        expect(SDK::Reader.read_integer(reader)).to eql(0)
      end

    end

    context "given an invalid value" do

      it "raises an error" do
        reader = SDK::XmlReader.new('<value>ugly</value>')
        expect { SDK::Reader.read_integer(reader) }.to raise_error(SDK::Error, /ugly/)
      end

    end

  end

  describe ".read_integers" do

    context "given no values with close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new('<list></list>')
        reader.read
        expect(SDK::Reader.read_integers(reader)).to eql([])
      end
    end

    context "given no values without close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new('<list/>')
        reader.read
        expect(SDK::Reader.read_integers(reader)).to eql([])
      end
    end

    context "given one value" do
      it "returns a list containing the value" do
        reader = SDK::XmlReader.new('<list><value>0</value></list>')
        reader.read
        expect(SDK::Reader.read_integers(reader)).to eql([0])
      end
    end

    context "given two values" do
      it "returns a list containing the two values" do
        reader = SDK::XmlReader.new('<list><value>0</value><value>1</value></list>')
        reader.read
        expect(SDK::Reader.read_integers(reader)).to eql([0, 1])
      end
    end

  end

  describe ".read_decimal" do

    context "given a valid value" do

      it "returns that value" do
        reader = SDK::XmlReader.new('<value>1.0</value>')
        expect(SDK::Reader.read_decimal(reader)).to eql(1.0)
      end

    end

    context "given an invalid value" do

      it "raises an error" do
        reader = SDK::XmlReader.new('<value>ugly</value>')
        expect { SDK::Reader.read_decimal(reader) }.to raise_error(SDK::Error, /ugly/)
      end

    end

  end

  describe ".read_decimals" do

    context "given no values with close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new('<list></list>')
        reader.read
        expect(SDK::Reader.read_decimals(reader)).to eql([])
      end
    end

    context "given no values without close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new('<list/>')
        reader.read
        expect(SDK::Reader.read_decimals(reader)).to eql([])
      end
    end

    context "given one value" do
      it "returns a list containing the value" do
        reader = SDK::XmlReader.new('<list><value>1.1</value></list>')
        reader.read
        expect(SDK::Reader.read_decimals(reader)).to eql([1.1])
      end
    end

    context "given two values" do
      it "returns a list containing the two values" do
        reader = SDK::XmlReader.new('<list><value>1.1</value><value>2.2</value></list>')
        reader.read
        expect(SDK::Reader.read_decimals(reader)).to eql([1.1, 2.2])
      end
    end

  end

  describe ".read_date" do

    context "given a valid date" do

      it "returns that date" do
        reader = SDK::XmlReader.new('<value>2015-12-10T22:00:30+01:00</value>')
        date = DateTime.new(2015, 12, 10, 22, 00, 30, '+1')
        expect(SDK::Reader.read_date(reader)).to eql(date)
      end

    end

    context "given an invalid value" do

      it "raises an error" do
        reader = SDK::XmlReader.new('<value>ugly</value>')
        expect { SDK::Reader.read_date(reader) }.to raise_error(SDK::Error, /ugly/)
      end

    end

  end

  describe ".read_dates" do

    context "given no values with close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new('<list></list>')
        reader.read
        expect(SDK::Reader.read_dates(reader)).to eql([])
      end
    end

    context "given no values without close tag" do
      it "returns empty list" do
        reader = SDK::XmlReader.new('<list/>')
        reader.read
        expect(SDK::Reader.read_dates(reader)).to eql([])
      end
    end

    context "given one value" do
      it "returns a list containing the value" do
        reader = SDK::XmlReader.new(
          '<list>' +
            '<value>2015-12-10T22:00:30+01:00</value>' +
          '</list>'
        )
        reader.read
        dates = [
          DateTime.new(2015, 12, 10, 22, 00, 30, '+1'),
        ]
        expect(SDK::Reader.read_dates(reader)).to eql(dates)
      end
    end

    context "given two values" do
      it "returns a list containing the two values" do
        reader = SDK::XmlReader.new(
          '<list>' +
            '<value>2015-12-10T22:00:30+01:00</value>' +
            '<value>2016-12-10T22:00:30+01:00</value>' +
          '</list>'
        )
        reader.read
        dates = [
          DateTime.new(2015, 12, 10, 22, 00, 30, '+1'),
          DateTime.new(2016, 12, 10, 22, 00, 30, '+1'),
        ]
        expect(SDK::Reader.read_dates(reader)).to eql(dates)
      end
    end

  end

end
