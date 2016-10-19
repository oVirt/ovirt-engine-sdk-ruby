#
# Copyright (c) 2015-2016 Red Hat, Inc.
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

  describe '.new' do
    context 'in secure mode' do
      it 'no exception is raised if no CA certificate is provided' do
        connection = SDK::Connection.new(
          url:      test_url,
          username: test_user,
          password: test_password,
          debug:    test_debug,
          log:      test_log
        )
        connection.close
      end

      it 'no exception is raised if a CA certificate is provided' do
        connection = SDK::Connection.new(
          url:      test_url,
          username: test_user,
          password: test_password,
          ca_file:  test_ca_file,
          debug:    test_debug,
          log:      test_log
        )
        connection.close
      end
    end

    context 'in insecure mode' do
      it 'a CA certificate is not required' do
        connection = SDK::Connection.new(
          url:      test_url,
          username: test_user,
          password: test_password,
          insecure: true,
          debug:    test_debug,
          log:      test_log
        )
        connection.close
      end
    end

    context 'with Kerberos enabled' do
      it 'works correctly' do
        connection = SDK::Connection.new(
          url:      test_url,
          kerberos: true,
          ca_file:  test_ca_file,
          debug:    test_debug,
          log:      test_log
        )
        connection.close
      end
    end

    context 'with version suffix' do
      it 'works correctly' do
        connection = SDK::Connection.new(
          url:     "#{test_url}/v4",
          ca_file: test_ca_file,
          debug:   test_debug,
          log:     test_log
        )
        connection.close
      end
    end

    context 'with token and no user or password' do
      it 'works correctly' do
        connection = SDK::Connection.new(
          url:     test_url,
          token:   test_token,
          ca_file: test_ca_file,
          debug:   test_debug,
          log:     test_log
        )
        connection.close
      end
    end
  end

  describe '#authenticate' do
    context 'with user name and password' do
      it 'returns the expected token' do
        connection = SDK::Connection.new(
          url:      test_url,
          username: test_user,
          password: test_password,
          ca_file:  test_ca_file,
          debug:    test_debug,
          log:      test_log
        )
        token = connection.authenticate
        expect(token).to eql(test_token)
        connection.close
      end
    end

    context 'with Kerberos' do
      it 'returns the expected token' do
        connection = SDK::Connection.new(
          url:      test_url,
          kerberos: true,
          ca_file:  test_ca_file,
          debug:    test_debug,
          log:      test_log
        )
        token = connection.authenticate
        expect(token).to eql(test_token)
        connection.close
      end
    end

    context 'with token' do
      it 'returns the expected token' do
        connection = SDK::Connection.new(
          url:     test_url,
          token:   test_token,
          ca_file: test_ca_file,
          debug:   test_debug,
          log:     test_log
        )
        token = connection.authenticate
        expect(token).to eql(test_token)
        connection.close
      end
    end
  end
end
