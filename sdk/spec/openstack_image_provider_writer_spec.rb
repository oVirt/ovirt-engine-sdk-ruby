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

describe SDK::OpenStackImageProviderWriter do
  describe '.write_one' do
    it 'takes into account the XML schema naming exceptions and uses "openstack" instead of "open_stack"' do
      provider = SDK::OpenStackImageProvider.new
      writer = SDK::XmlWriter.new
      SDK::OpenStackImageProviderWriter.write_one(provider, writer)
      expect(writer.string).to eql('<openstack_image_provider/>')
      writer.close
    end
  end

  describe '.write_many' do
    it 'takes into account the XML schema naming exceptions and uses "openstack" instead of "open_stack"' do
      provider = SDK::OpenStackImageProvider.new
      providers = [provider, provider]
      writer = SDK::XmlWriter.new
      SDK::OpenStackImageProviderWriter.write_many(providers, writer)
      expect(writer.string).to eql(
        '<openstack_image_providers>' \
          '<openstack_image_provider/>' \
          '<openstack_image_provider/>' \
        '</openstack_image_providers>'
      )
      writer.close
    end
  end
end
