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

describe SDK::ClusterReader do
  describe '#read_one' do
    context 'given switch type after empty RNG sources' do
      it 'both are read correctly' do
        reader = SDK::XmlReader.new(
          '<cluster>' \
            '<required_rng_sources/>' \
            '<switch_type>legacy</switch_type>' \
          '</cluster>'
        )
        result = SDK::ClusterReader.read_one(reader)
        reader.close
        expect(result).to_not be_nil
        expect(result).to be_a(SDK::Cluster)
        expect(result.required_rng_sources).to eql([])
        expect(result.switch_type).to eql(SDK::SwitchType::LEGACY)
      end
    end
  end
end
