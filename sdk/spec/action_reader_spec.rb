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

describe SDK::ActionReader do

  describe ".read_one" do

    context "when given an empty XML" do

      it "creates the expected action" do
        reader = SDK::XmlReader.new('<fault/>')
        result = SDK::ActionReader.read_one(reader)
        reader.close
        expect(result).to be_a(SDK::Action)
        expect(result.status).to be_nil
        expect(result.fault).to be_nil
      end

    end

    context "when given status" do

      it "creates the expected action" do
        reader = SDK::XmlReader.new(
          '<action><status><state>mystate</state></status></action>'
        )
        result = SDK::ActionReader.read_one(reader)
        expect(result).to_not be_nil
        expect(result).to be_a(SDK::Action)
        expect(result.status).to be_a(SDK::Status)
        expect(result.status.state).to eql('mystate')
      end

    end

    context "when given fault" do

      it "creates the expected action" do
        reader = SDK::XmlReader.new(
          '<action><fault><reason>myreason</reason></fault></action>'
        )
        result = SDK::ActionReader.read_one(reader)
        expect(result).to be_a(SDK::Action)
        expect(result.fault).to be_a(SDK::Fault)
        expect(result.fault.reason).to eql('myreason')
      end

    end

    context "when given status and fault" do

      it "creates the expected action" do
        reader = SDK::XmlReader.new(
          '<action>' +
            '<status><state>mystate</state></status>' +
            '<fault><reason>myreason</reason></fault>' +
          '</action>'
        )
        result = SDK::ActionReader.read_one(reader)
        expect(result).to be_a(SDK::Action)
        expect(result.status).to be_a(SDK::Status)
        expect(result.status.state).to eql('mystate')
        expect(result.fault).to be_a(SDK::Fault)
        expect(result.fault.reason).to eql('myreason')
      end

    end

  end

end
