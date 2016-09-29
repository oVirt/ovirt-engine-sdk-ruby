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
        mount_xml(path: 'vms/123/start', body: '<action/>')
        @service.start(:pause => true)
        expect(last_request_method).to eq('POST')
        expect(last_request_body).to eq(
          "<action>\n" +
          "  <pause>true</pause>\n" +
          "</action>\n"
        )
      end

    end

    context 'when the server returns an action containing a fault' do

      it 'raises an error containing the information of the fault' do
        mount_xml(
          path: 'vms/123/start',
          body:
           '<action>' +
             '<fault>' +
               '<reason>myreason</reason>' +
             '</fault>' +
           '</action>'
        )
        expect { @service.start }.to raise_error(SDK::Error, /myreason/)
      end

    end

    context 'when the server returns an fault instead of an action' do

      it 'raises an error containing the information of the fault' do
        mount_xml(
          path: 'vms/123/start',
          status: 400,
          body:
            '<fault>' +
              '<reason>myreason</reason>' +
            '</fault>'
        )
        expect { @service.start }.to raise_error(SDK::Error, /myreason/)
      end

    end

  end

  describe '#update' do

      context 'when update a VM with the `async` parameter' do

        it 'puts an `vm` element with an `async` query parameter' do
          mount_xml(path: 'vms/123', body: '<vm><name>newname</name></vm>')
          @service.update(
            SDK::Vm.new({:name => 'newname'}),
            :async => true
          )
          expect(last_request_method).to eq('PUT')
          expect(last_request_query).to eq('async=true')
          expect(last_request_body).to eq(
            "<vm>\n" +
            "  <name>newname</name>\n" +
            "</vm>\n"
          )
        end

      end
   end

end
