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

describe SDK::SsoWriter do
  describe '#write_one' do
    it 'writes the SSO method identifier as an XML attribute' do
      network = SDK::Sso.new(
        methods: [
          SDK::Method.new(
            id: SDK::SsoMethod::GUEST_AGENT
          )
        ]
      )
      result = SDK::Writer.write(network)
      expect(result).to eql(
        '<sso>' \
          '<methods>' \
            '<method id="guest_agent"/>' \
          '</methods>' \
        '</sso>'
      )
    end
  end
end
