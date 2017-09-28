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

describe 'multiple thread support' do
  before(:all) do
    start_server
    @connection = test_connection
    @events_service = @connection.system_service.events_service
    @users_service = @connection.system_service.users_service
  end

  after(:all) do
    @connection.close
    stop_server
  end

  it 'supports two threads using simultaneously the same connection' do
    mount_xml(path: 'events', body: '<event/>')
    mount_xml(path: 'users', body: '<users/>')
    events_thread = Thread.new do
      100.times do
        @events_service.list
      end
    end
    users_thread = Thread.new do
      100.times do
        @users_service.list
      end
    end
    events_thread.join
    users_thread.join
  end
end
