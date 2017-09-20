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
  end

  after(:all) do
    stop_server
  end

  it 'throws an auth error when the user name is incorrect' do
    @connection = SDK::Connection.new(
      url:      test_url,
      username: 'bad.user',
      password: test_password,
      ca_file:  test_ca_file,
      debug:    test_debug,
      log:      test_log
    )
    expect { @connection.authenticate }.to raise_error(SDK::AuthError)
  end

  it 'throws an auth error when the password is incorrect' do
    @connection = SDK::Connection.new(
      url:      test_url,
      username: test_user,
      password: 'bad.password',
      ca_file:  test_ca_file,
      debug:    test_debug,
      log:      test_log
    )
    expect { @connection.authenticate }.to raise_error(SDK::AuthError)
  end

  it 'throws an auth error when the server returns an authorization error code' do
    mount_xml(path: 'vms', status: 401, body: '<fault/>')
    @connection = SDK::Connection.new(
      url:      test_url,
      username: test_user,
      password: test_password,
      ca_file:  test_ca_file,
      debug:    test_debug,
      log:      test_log
    )
    vms_service = @connection.system_service.vms_service
    expect { vms_service.list }.to raise_error(SDK::AuthError)
  end
end
