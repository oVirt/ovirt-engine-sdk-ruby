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

describe SDK::Connection do
  before(:all) do
    start_server
    mount_xml(path: '', body: '<api/>')
  end

  after(:all) do
    stop_server
  end

  let(:connection) do
    test_connection
  end

  describe '#inspect' do
    it 'contains the URL' do
      expect(connection.inspect).to include(test_url)
    end

    it 'does not contain the user name' do
      expect(connection.inspect).to_not include(test_user)
    end

    it 'does not contain the password' do
      expect(connection.inspect).to_not include(test_password)
    end
  end

  describe '#to_s' do
    it 'contains the URL' do
      expect(connection.to_s).to include(test_url)
    end

    it 'does not contain the user name' do
      expect(connection.to_s).to_not include(test_user)
    end

    it 'does not contain the password' do
      expect(connection.to_s).to_not include(test_password)
    end
  end
end
