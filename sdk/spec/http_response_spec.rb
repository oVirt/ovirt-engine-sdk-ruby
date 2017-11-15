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

describe SDK::HttpResponse do
  let(:response) do
    response = SDK::HttpResponse.new
    response.code = 404
    response.message = 'Not found'
    response.body = 'mybody'
    response
  end

  describe '#inspect' do
    it 'contains the code' do
      expect(response.inspect).to include(response.code.to_s)
    end

    it 'contains the message' do
      expect(response.inspect).to include(response.message)
    end

    it 'does not contains the body' do
      expect(response.inspect).not_to include(response.body)
    end
  end

  describe '#to_s' do
    it 'contains the code' do
      expect(response.to_s).to include(response.code.to_s)
    end

    it 'contains the message' do
      expect(response.to_s).to include(response.message)
    end

    it 'does not contains the body' do
      expect(response.to_s).not_to include(response.body)
    end
  end
end
