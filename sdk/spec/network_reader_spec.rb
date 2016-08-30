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

describe SDK::NetworkReader do

  describe '#read_one' do

    context 'when given a network with no usages' do
      it 'the value of the usages attribute is nil' do
        reader = SDK::XmlReader.new(
          '<network/>'
        )
        result = SDK::NetworkReader.read_one(reader)
        reader.close
        expect(result.usages).to be_nil
      end
    end

    context 'when given a network with an empty usages' do
      it 'creates an empty array of usages' do
        reader = SDK::XmlReader.new(
          '<network>' +
            '<usages/>' +
          '</network>'
        )
        result = SDK::NetworkReader.read_one(reader)
        reader.close
        expect(result.usages).to be_a(Array)
        expect(result.usages.length).to eql(0)
      end
    end

    context 'when given a network with one usage' do
      it 'creates an array containing one usage' do
        reader = SDK::XmlReader.new(
          '<network>' +
            '<usages>' +
              '<usage>vm</usage>' +
            '</usages>' +
          '</network>'
        )
        result = SDK::NetworkReader.read_one(reader)
        reader.close
        expect(result.usages).to be_a(Array)
        expect(result.usages.length).to eql(1)
        expect(result.usages[0]).to eql(SDK::NetworkUsage::VM)
      end
    end

    context 'when given network with two usages' do
      it 'creates an array containing two usage' do
        reader = SDK::XmlReader.new(
          '<network>' +
            '<usages>' +
              '<usage>vm</usage>' +
              '<usage>display</usage>' +
            '</usages>' +
          '</network>'
        )
        result = SDK::NetworkReader.read_one(reader)
        reader.close
        expect(result).to be_a(SDK::Network)
        expect(result.usages).to be_a(Array)
        expect(result.usages.length).to eql(2)
        expect(result.usages[0]).to eql(SDK::NetworkUsage::VM)
        expect(result.usages[1]).to eql(SDK::NetworkUsage::DISPLAY)
      end
    end

  end

end
