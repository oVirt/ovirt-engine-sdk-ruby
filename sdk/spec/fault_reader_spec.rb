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

describe SDK::FaultReader do

  describe ".read_one" do

    context "when given an empty XML" do

      it "creates the expected fault" do
        reader = SDK::XmlReader.new('<fault/>')
        result = SDK::FaultReader.read_one(reader)
        reader.close
        expect(result).to_not be_nil
        expect(result).to be_a(SDK::Fault)
        expect(result.reason).to be_nil
        expect(result.detail).to be_nil
      end

    end

    context "when given only reason" do

      it "creates the expected fault" do
        reader = SDK::XmlReader.new('<fault><reason>myreason</reason></fault>')
        result = SDK::FaultReader.read_one(reader)
        expect(result).to_not be_nil
        expect(result).to be_a(SDK::Fault)
        expect(result.reason).to eql('myreason')
        expect(result.detail).to be_nil
      end

    end

    context "when given only detail" do

      it "creates the expected fault" do
        reader = SDK::XmlReader.new('<fault><detail>mydetail</detail></fault>')
        result = SDK::FaultReader.read_one(reader)
        expect(result).to_not be_nil
        expect(result).to be_a(SDK::Fault)
        expect(result.reason).to be_nil
        expect(result.detail).to eql('mydetail')
      end

    end

    context "when given reason and detail" do

      it "creates the expected fault" do
        reader = SDK::XmlReader.new(
          '<fault><reason>myreason</reason><detail>mydetail</detail></fault>'
        )
        result = SDK::FaultReader.read_one(reader)
        expect(result).to_not be_nil
        expect(result).to be_a(SDK::Fault)
        expect(result.reason).to eql('myreason')
        expect(result.detail).to eql('mydetail')
      end

    end

  end

end
