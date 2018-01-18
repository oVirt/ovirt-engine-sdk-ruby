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

describe SDK::Future do
  let(:future) do
    request = SDK::HttpRequest.new
    request.method = :GET
    request.url = test_url
    request.body = 'mybody'
    request.username = test_user
    request.password = test_password
    SDK::Future.new(nil, request) {}
  end

  describe '#inspect' do
    it 'contains the method' do
      expect(future.inspect).to include('GET')
    end

    it 'contains the URL' do
      expect(future.inspect).to include(test_url)
    end

    it 'does not contain the body' do
      expect(future.inspect).not_to include('mybody')
    end

    it 'does not contain the user name' do
      expect(future.inspect).not_to include(test_user)
    end

    it 'does not contain the password' do
      expect(future.inspect).not_to include(test_password)
    end
  end

  describe '#to_s' do
    it 'contains the method' do
      expect(future.to_s).to include('GET')
    end

    it 'contains the URL' do
      expect(future.to_s).to include(test_url)
    end

    it 'does not contain the body' do
      expect(future.to_s).not_to include('mybody')
    end

    it 'does not contain the user name' do
      expect(future.to_s).not_to include(test_user)
    end

    it 'does not contain the password' do
      expect(future.to_s).not_to include(test_password)
    end
  end
end
