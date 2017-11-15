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

describe SDK::HttpClient do
  let(:client) do
    client = SDK::HttpClient.new(
      proxy_username: 'myproxyuser',
      proxy_password: 'myproxypassword'
    )
    client
  end

  describe '#inspect' do
    it 'does not contain the proxy user name' do
      expect(client.inspect).not_to include('myproxyuser')
    end

    it 'does not contain the proxy password' do
      expect(client.inspect).not_to include('myproxypassword')
    end
  end

  describe '#to_s' do
    it 'does not contain the proxy user name' do
      expect(client.to_s).not_to include('myproxyuser')
    end

    it 'does not contain the proxy password' do
      expect(client.to_s).not_to include('myproxypassword')
    end
  end
end
