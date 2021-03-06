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

describe SDK::DiskAttachmentService do
  before(:all) do
    start_server
    @connection = test_connection
    @service = @connection
      .system_service
      .vms_service.vm_service('123')
      .disk_attachments_service
      .attachment_service('456')
  end

  after(:all) do
    @connection.close
    stop_server
  end

  describe '#get' do
    it 'builds the path correctly' do
      mount_xml(path: 'vms/123/diskattachments/456', body: '<disk_attachment/>')
      @service.get
      expect(last_request_path).to eq('/ovirt-engine/api/vms/123/diskattachments/456')
    end
  end
end
