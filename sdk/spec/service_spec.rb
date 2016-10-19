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

describe SDK::Service do
  describe '#check_fault' do
    context 'given a fault' do
      before(:all) do
        @service = SDK::Service.new
        @response = SDK::HttpResponse.new(
          code:    209,
          message: 'mymessage',
          body:    '<fault><reason>myreason</reason><detail>mydetail</detail></fault>'
        )
      end

      it 'raises an exception containing the code' do
        expect { @service.check_fault(@response) }.to raise_error(SDK::Error, /209/)
      end

      it 'raises an exception containing the message' do
        expect { @service.check_fault(@response) }.to raise_error(SDK::Error, /mymessage/)
      end

      it 'raises an exception containing the reason' do
        expect { @service.check_fault(@response) }.to raise_error(SDK::Error, /myreason/)
      end

      it 'raises an exception containing the detail' do
        expect { @service.check_fault(@response) }.to raise_error(SDK::Error, /mydetail/)
      end
    end

    context 'given an empty response, with blank body' do
      before(:all) do
        @service = SDK::Service.new
        @response = SDK::HttpResponse.new(
          code:    209,
          message: 'mymessage',
          body:    ''
        )
      end

      it 'raises an exception containing the code' do
        expect { @service.check_fault(@response) }.to raise_error(SDK::Error, /209/)
      end

      it 'raises an exception containing the message' do
        expect { @service.check_fault(@response) }.to raise_error(SDK::Error, /mymessage/)
      end
    end

    context 'given an empty response, with nil body' do
      before(:all) do
        @service = SDK::Service.new
        @response = SDK::HttpResponse.new(
          code:    209,
          message: 'mymessage',
          body:    nil
        )
      end

      it 'raises an exception containing the code' do
        expect { @service.check_fault(@response) }.to raise_error(SDK::Error, /209/)
      end

      it 'raises an exception containing the message' do
        expect { @service.check_fault(@response) }.to raise_error(SDK::Error, /mymessage/)
      end
    end
  end

  describe '#check_action' do
    context 'given an empty response, with nil body' do
      it 'raises an error containing the response code' do
        service = SDK::Service.new
        response = SDK::HttpResponse.new(code: 209, body: nil)
        expect { service.check_action(response) }.to raise_error(SDK::Error, /209/)
      end
    end

    context 'given an empty response, with blank body' do
      it 'raises an error containing the response code' do
        service = SDK::Service.new
        response = SDK::HttpResponse.new(code: 209, body: '')
        expect { service.check_action(response) }.to raise_error(SDK::Error, /209/)
      end
    end

    context 'given no fault' do
      before(:all) do
        @service = SDK::Service.new
        @response = SDK::HttpResponse.new(
          body: '<action><status><state>mystate</state></status></action>'
        )
      end

      it 'does not raise an exception' do
        @service.check_action(@response)
      end
    end

    context 'given a fault' do
      before(:all) do
        @service = SDK::Service.new
        @response = SDK::HttpResponse.new(
          body: '<action><fault><reason>myreason</reason></fault></action>'
        )
      end

      it 'raises an exception' do
        expect { @service.check_action(@response) }.to raise_error(SDK::Error, /myreason/)
      end
    end

    context 'given a fault instead of an action' do
      it 'raises an error containing the fault reason' do
        service = SDK::Service.new
        response = SDK::HttpResponse.new(
          body: '<fault><reason>myreason</reason></fault>'
        )
        expect { service.check_action(response) }.to raise_error(SDK::Error, /myreason/)
      end
    end
  end
end
