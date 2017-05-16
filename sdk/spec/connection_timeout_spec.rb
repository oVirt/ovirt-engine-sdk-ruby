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
  end

  after(:all) do
    stop_server
  end

  describe '#send' do
    context 'when global timeout is set and request timeout is not set' do
      before(:each) do
        @connection = SDK::Connection.new(
          url:      test_url,
          username: test_user,
          password: test_password,
          ca_file:  test_ca_file,
          timeout:  1,
          debug:    test_debug,
          log:      test_log
        )
        @service = @connection.system_service.vms_service
      end

      after(:each) do
        @connection.close
      end

      it 'fails when the global timeout expires' do
        mount_xml(path: 'vms', body: '<vms/>', delay: 2)
        expect { @service.list }.to raise_error(/timeout/i)
      end
    end

    context 'when global timeout is lower than request timeout' do
      before(:each) do
        @connection = SDK::Connection.new(
          url:      test_url,
          username: test_user,
          password: test_password,
          ca_file:  test_ca_file,
          timeout:  1,
          debug:    test_debug,
          log:      test_log
        )
        @service = @connection.system_service.vms_service
      end

      after(:each) do
        @connection.close
      end

      it 'fails when the global timeout expires' do
        mount_xml(path: 'vms', body: '<vms/>', delay: 3)
        expect { @service.list(timeout: 2) }.to raise_error(/timeout/i)
      end
    end

    context 'when global timeout is greater than request timeout' do
      before(:each) do
        @connection = SDK::Connection.new(
          url:      test_url,
          username: test_user,
          password: test_password,
          ca_file:  test_ca_file,
          timeout:  3,
          debug:    test_debug,
          log:      test_log
        )
        @service = @connection.system_service.vms_service
      end

      after(:each) do
        @connection.close
      end

      it 'fails when the request timeout expires' do
        mount_xml(path: 'vms', body: '<vms/>', delay: 2)
        expect { @service.list(timeout: 1) }.to raise_error(/timeout/i)
      end
    end

    context 'when no global timeout is set but request timeout is set' do
      before(:each) do
        @connection = SDK::Connection.new(
          url:      test_url,
          username: test_user,
          password: test_password,
          ca_file:  test_ca_file,
          debug:    test_debug,
          log:      test_log
        )
        @service = @connection.system_service.vms_service
      end

      after(:each) do
        @connection.close
      end

      it 'fails when the request timeout expires' do
        mount_xml(path: 'vms', body: '<vms/>', delay: 2)
        expect { @service.list(timeout: 1) }.to raise_error(/timeout/i)
      end
    end
  end
end
