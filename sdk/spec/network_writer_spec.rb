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

describe SDK::NetworkWriter do
  describe '#write_one' do
    context 'when usages is nil' do
      it 'writes the expected XML' do
        network = SDK::Network.new
        result = SDK::Writer.write(network)
        expect(result).to eql('<network/>')
      end
    end

    context 'when usages is empty' do
      it 'writes the expected XML' do
        network = SDK::Network.new(
          usages: []
        )
        result = SDK::Writer.write(network)
        expect(result).to eql(
          '<network>' \
            '<usages/>' \
          '</network>'
        )
      end
    end

    context 'when there is one usage' do
      it 'writes the expected XML' do
        network = SDK::Network.new(
          usages: [
            SDK::NetworkUsage::VM
          ]
        )
        result = SDK::Writer.write(network)
        expect(result).to eql(
          '<network>' \
            '<usages>' \
              '<usage>vm</usage>' \
            '</usages>' \
          '</network>'
        )
      end
    end

    context 'when there are two usages' do
      it 'writes the expected XML' do
        network = SDK::Network.new(
          usages: [
            SDK::NetworkUsage::VM,
            SDK::NetworkUsage::DISPLAY
          ]
        )
        result = SDK::Writer.write(network)
        expect(result).to eql(
          '<network>' \
            '<usages>' \
              '<usage>vm</usage>' \
              '<usage>display</usage>' \
            '</usages>' \
          '</network>'
        )
      end
    end
  end
end
