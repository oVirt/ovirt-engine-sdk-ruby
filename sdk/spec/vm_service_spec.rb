#
# Copyright (c) 2016 Red Hat, Inc.
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

require 'spec_helper'

describe SDK::VmService do

  before(:all) do
    start_server
    @connection = test_connection
    @service = @connection.system_service.vms_service.vm_service('123')
  end

  after(:all) do
    @connection.close
    stop_server
  end

  describe ".start" do

    context "when starting a VM with the `pause` parameter" do

      it "posts an `action` element with an inner `pause` element" do
        set_xml_response('vms/123/start', 200, '<action/>')
        @service.start(:pause => true)
        expect(last_request_method).to eq('POST')
        expect(last_request_body).to eq(
          "<action>\n" +
          "  <pause>true</pause>\n" +
          "</action>\n"
        )
      end

    end

  end

end
