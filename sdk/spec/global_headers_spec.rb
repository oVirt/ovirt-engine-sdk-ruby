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

describe 'global headers:' do
  before(:all) do
    start_server
    @connection = SDK::Connection.new(
      test_connection_options.merge(
        headers: {
          my: 'myvalue'
        }
      )
    )
    @vms = @connection.system_service.vms_service
    @vm = @vms.vm_service('123')
  end

  after(:all) do
    @connection.close
    stop_server
  end

  describe 'list' do
    it 'sends the custom global header' do
      mount_xml(path: 'vms', body: '<vms/>')
      @vms.list
      expect(last_request_headers['my']).to eq(['myvalue'])
    end

    it 'uses local instead of global' do
      mount_xml(path: 'vms', body: '<vms/>')
      @vms.list(headers: { my: 'mylocal' })
      expect(last_request_headers['my']).to eq(['mylocal'])
    end
  end

  describe 'add' do
    it 'sends the custom global header' do
      mount_xml(path: 'vms', body: '<vm/>')
      @vms.add(SDK::Vm.new)
      expect(last_request_headers['my']).to eq(['myvalue'])
    end

    it 'uses local instead of global' do
      mount_xml(path: 'vms', body: '<vm/>')
      @vms.add(SDK::Vm.new, headers: { my: 'mylocal' })
      expect(last_request_headers['my']).to eq(['mylocal'])
    end
  end

  describe 'get' do
    it 'sends the custom global header' do
      mount_xml(path: 'vms/123', body: '<vm/>')
      @vm.get
      expect(last_request_headers['my']).to eq(['myvalue'])
    end

    it 'uses local instead of global' do
      mount_xml(path: 'vms/123', body: '<vm/>')
      @vm.get(headers: { my: 'mylocal' })
      expect(last_request_headers['my']).to eq(['mylocal'])
    end
  end

  describe 'update' do
    it 'sends the custom global header' do
      mount_xml(path: 'vms/123', body: '<vm/>')
      @vm.update(SDK::Vm.new)
      expect(last_request_headers['my']).to eq(['myvalue'])
    end

    it 'uses local instead of global' do
      mount_xml(path: 'vms/123', body: '<vm/>')
      @vm.update(SDK::Vm.new, headers: { my: 'mylocal' })
      expect(last_request_headers['my']).to eq(['mylocal'])
    end
  end
end
