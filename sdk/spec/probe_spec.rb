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

API_V3_RESPONSE = '<api><version major=\"4\" minor=\"1\" build=\"0\" revision=\"0\"/></api>'
API_V4_RESPONSE = '<api><version>  <major>4</major>\n <minor>1</minor>\n </version>  </api>'

def set_support_only_api_v3
  set_xml_response('', 200, API_V3_RESPONSE, 0, '')
end

def set_support_only_api_v4
  set_xml_response('', 200, API_V4_RESPONSE, 0, '')
end

def set_support_for_api_v3_and_v4
  set_xml_response('', 200,'',0, '',conditional_api_response_lambda)
end

def conditional_api_response_lambda
  -> (req) do
    case req["version"]
    when "3"
      return API_V3_RESPONSE
    when "4"
      return API_V4_RESPONSE
    end
  end
end

describe SDK::Probe do
  context '#probe' do
    let(:probe_params) do
      {
        :host => test_host,
        :port => test_port,
        :username => test_user,
        :password => test_password,
        :log => test_log,
        :debug => true
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
