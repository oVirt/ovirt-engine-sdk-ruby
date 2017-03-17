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
    @connection = test_connection
  end

  after(:all) do
    @connection.close
    stop_server
  end

  describe '#send' do
    context 'GET of root' do
      it 'just works' do
        mount_xml(path: '', body: '<api/>')
        request = SDK::HttpRequest.new
        @connection.send(request)
        response = @connection.wait(request)
        expect(response).to be_a(SDK::HttpResponse)
        expect(response.code).to eql(200)
      end
    end
  end

  describe '#service' do
    context 'given nil' do
      it 'returns a reference to the system service' do
        result = @connection.service(nil)
        expect(result).to be_a(SDK::SystemService)
      end
    end

    context 'given empty string' do
      it 'returns a reference to the system service' do
        result = @connection.service(nil)
        expect(result).to be_a(SDK::SystemService)
      end
    end

    context 'given "vms"' do
      it 'returns a reference to the virtual machines service' do
        result = @connection.service('vms')
        expect(result).to be_a(SDK::VmsService)
      end
    end

    context 'given "vms/123"' do
      it 'returns a reference to the virtual machine service' do
        result = @connection.service('vms/123')
        expect(result).to be_a(SDK::VmService)
      end
    end

    context 'given "vms/123/diskattachments"' do
      it 'returns a reference to the virtual machine disk attachments service' do
        result = @connection.service('vms/123/diskattachments')
        expect(result).to be_a(SDK::DiskAttachmentsService)
      end
    end
  end
end
