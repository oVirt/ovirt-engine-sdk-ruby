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

describe SDK::HttpRequest do
  let(:request) do
    request = SDK::HttpRequest.new
    request.method = :GET
    request.url = test_url
    request.body = 'mybody'
    request.username = test_user
    request.password = test_password
    request
  end

  describe '#inspect' do
    it 'contains the method' do
      expect(request.inspect).to include(request.method.to_s)
    end

    it 'contains the URL' do
      expect(request.inspect).to include(request.url)
    end

    it 'does not contain the body' do
      expect(request.inspect).not_to include(request.body)
    end

    it 'does not contain the user name' do
      expect(request.inspect).not_to include(request.username)
    end

    it 'does not contain the password' do
      expect(request.inspect).not_to include(request.password)
    end
  end

  describe '#to_s' do
    it 'contains the method' do
      expect(request.to_s).to include(request.method.to_s)
    end

    it 'contains the URL' do
      expect(request.to_s).to include(request.url)
    end

    it 'does not contain the body' do
      expect(request.to_s).not_to include(request.body)
    end

    it 'does not contain the user name' do
      expect(request.to_s).not_to include(request.username)
    end

    it 'does not contain the password' do
      expect(request.to_s).not_to include(request.password)
    end
  end
end
