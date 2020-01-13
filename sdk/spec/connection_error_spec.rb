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
  it 'throws a connection error when the server address can not be resolved' do
    @connection = SDK::Connection.new(
      url:      'https://bad.host/ovirt-engine/api',
      username: test_user,
      password: test_password,
      ca_file:  test_ca_file,
      debug:    test_debug,
      log:      test_log
    )
    expect { @connection.test(raise_exception: true) }.to raise_error(SDK::ConnectionError, /host name/)
  end

  it 'throws an connection error when the proxy address can not be resolved' do
    @connection = SDK::Connection.new(
      url:       'https://bad.host/ovirt-engine/api',
      username:  test_user,
      password:  test_password,
      ca_file:   test_ca_file,
      debug:     test_debug,
      log:       test_log,
      proxy_url: 'http://bad.proxy'
    )
    expect { @connection.test(raise_exception: true) }.to raise_error(SDK::ConnectionError, /proxy name/)
  end

  it 'throws an connection error when the server address is incorrect' do
    @connection = SDK::Connection.new(
      url:      'https://300.300.300.300/ovirt-engine/api',
      username: test_user,
      password: test_password,
      ca_file:  test_ca_file,
      debug:    test_debug,
      log:      test_log
    )
    expect { @connection.test(raise_exception: true) }.to raise_error(SDK::ConnectionError, /host name/)
  end

  it 'throws an connection error when the proxy address is incorrect' do
    @connection = SDK::Connection.new(
      url:       'https://bad.host/ovirt-engine/api',
      username:  test_user,
      password:  test_password,
      ca_file:   test_ca_file,
      debug:     test_debug,
      log:       test_log,
      proxy_url: 'http://300.300.300.300'
    )
    expect { @connection.test(raise_exception: true) }.to raise_error(SDK::ConnectionError, /proxy name/)
  end

  it 'throws an connection error when the server is down' do
    @connection = SDK::Connection.new(
      url:      test_url,
      username: test_user,
      password: test_password,
      ca_file:  test_ca_file,
      debug:    test_debug,
      log:      test_log
    )
    expect { @connection.test(raise_exception: true) }.to raise_error(SDK::ConnectionError)
  end
end
