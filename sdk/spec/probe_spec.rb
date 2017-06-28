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

API_V3_RESPONSE = '<api><version major="4" minor="1" build="0" revision="0"/></api>'.freeze
API_V4_RESPONSE = '<api><version><major>4</major><minor>1</minor></version></api>'.freeze

def set_support_only_api_v3
  mount_raw(path: '/api') do |_, response|
    response.status = 200
    response.body = API_V3_RESPONSE
  end
end

def set_support_only_api_v4
  mount_raw(path: '/ovirt-engine/api') do |_, response|
    response.status = 200
    response.body = API_V4_RESPONSE
  end
end

def set_ssh_certificates_exists
  mount_raw(path: SDK::Probe::ENGINE_CERTIFICATE_PATH.split('?')[0]) do |request, response|
    query_for_certificate = SDK::Probe::ENGINE_CERTIFICATE_PATH.split('?')[1]
    response.status = request.meta_vars['QUERY_STRING'] == query_for_certificate ? 200 : 404
  end
end

def set_support_for_api_v3_and_v4
  mount_raw(path: '/ovirt-engine/api') do |request, response|
    version = request['Version']
    response.status = 200
    response.body =
      case version
      when '3'
        API_V3_RESPONSE
      else
        API_V4_RESPONSE
      end
  end
end

describe SDK::Probe do
  context '#exists?' do
    let(:probe_params) do
      {
        host:     test_host,
        port:     test_port,
        insecure: true,
        log:      test_log,
        debug:    true
      }
    end

    context 'engine certificate exists' do
      before(:all) do
        start_server
        set_ssh_certificates_exists
      end

      after(:all) do
        stop_server
      end

      it 'returns true when server exists' do
        expect(described_class.exists?(probe_params)).to eq(true)
      end
    end

    context 'engine certificate is missing' do
      before(:all) do
        start_server
      end

      after(:all) do
        stop_server
      end

      it 'returns false when server is missing' do
        expect(described_class.exists?(probe_params)).to eq(false)
      end
    end
  end

  context '#probe' do
    let(:probe_params) do
      {
        host:     test_host,
        port:     test_port,
        insecure: true,
        username: test_user,
        password: test_password,
        log:      test_log,
        debug:    true
      }
    end

    let(:ver_3) { SDK::ProbeResult.new(version: '3') }
    let(:ver_4) { SDK::ProbeResult.new(version: '4') }

    context 'when api v3' do
      before(:all) do
        start_server
        set_support_only_api_v3
      end

      after(:all) do
        stop_server
      end

      it 'detects v3 api' do
        res = described_class.probe(probe_params)
        expect(res).to match_array([ver_3])
      end
    end

    context 'when supports both v3 and v4 api' do
      before(:all) do
        start_server
        set_support_for_api_v3_and_v4
      end

      after(:all) do
        stop_server
      end

      it 'detects v3 and v4 api' do
        res = described_class.probe(probe_params)
        expect(res).to match_array([ver_3, ver_4])
      end
    end

    context 'when supports only v4 api' do
      before(:all) do
        start_server
        set_support_only_api_v4
      end

      after(:all) do
        stop_server
      end

      it 'detects v4 api' do
        res = described_class.probe(probe_params)
        expect(res).to match_array([ver_4])
      end
    end
  end
end
