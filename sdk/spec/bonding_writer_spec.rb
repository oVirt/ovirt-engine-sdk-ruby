#
# Copyright (c) 2017 Red Hat, Inc.
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

describe SDK::BondingWriter do
  describe '.write_one' do
    it 'uses the name of the element type for lists of structs' do
      bonding = SDK::Bonding.new(
        slaves: [
          {
            name: 'eth0'
          },
          {
            name: 'eth1'
          }
        ]
      )
      writer = SDK::XmlWriter.new
      SDK::BondingWriter.write_one(bonding, writer)
      expect(writer.string).to eql(
        '<bonding>' \
          '<slaves>' \
            '<host_nic>' \
              '<name>eth0</name>' \
            '</host_nic>' \
            '<host_nic>' \
              '<name>eth1</name>' \
            '</host_nic>' \
          '</slaves>' \
        '</bonding>'
      )
      writer.close
    end
  end
end
