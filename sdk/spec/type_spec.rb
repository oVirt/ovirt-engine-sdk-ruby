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

describe SDK::Type do

  describe '#dig' do

    before(:all) do
      @event = SDK::Event.new(
        :id => 'e',
        :vm => {
          :id => 'v',
          :disk_attachments => [
            {
              :disk => {
                :id => 'd0',
              },
            },
            {
              :disk => {
                :id => 'd1',
              },
            },
          ],
        }
      )
    end

    context 'given an empty list of keys' do
      it 'returns self' do
        expect(@event.dig).to be(@event)
      end
    end

    context 'given one valid symbol' do
      it 'returns the value of the corresponding top level attribute' do
        expect(@event.dig(:id)).to eql('e')
      end
    end

    context 'given two valid symbols' do
      it 'returns the value of the corresponding attribute' do
        expect(@event.dig(:vm, :id)).to eql('v')
      end
    end

    context 'given index 0' do
      it 'returns the value of the corresponding attribute' do
        expect(@event.dig(:vm, :disk_attachments, 0, :disk, :id)).to eql('d0')
      end
    end

    context 'given index 1' do
      it 'returns the value of the corresponding attribute' do
        expect(@event.dig(:vm, :disk_attachments, 1, :disk, :id)).to eql('d1')
      end
    end

    context 'given nil first symbol' do
      it 'returns nil' do
        expect(@event.dig(:name)).to be_nil
      end
    end

    context 'given nil second symbol' do
      it 'returns nil' do
        expect(@event.dig(:cluster, :id)).to be_nil
      end
    end

    context 'given incorrect first symbol' do
      it 'throws exception' do
        expect { @event.dig(:junk) }.to raise_error(NoMethodError)
      end
    end

    context 'given incorrect second symbol' do
      it 'throws exception' do
        expect { @event.dig(:vm, :junk) }.to raise_error(NoMethodError)
      end
    end

    context 'given incorrect index' do
      it 'returns nil' do
        expect(@event.dig(:vm, :disk_attachments, 2)).to be_nil
      end
    end

  end

  describe '#==' do
    it 'returns false when given nil and non nil' do
      expect(SDK::Event.new == nil).to be false
    end

    it 'returns true when comparing an object to itself' do
      event = SDK::Event.new
      expect(event == event).to be true
    end

    it 'returns false when the types are different' do
      expect(SDK::VmBase.new == SDK::Vm.new).to be false
    end

    it 'returns true when the ids are equal and there are no more attributes' do
      first = SDK::Event.new(:id => 'ev1')
      second = SDK::Event.new(:id => 'ev1')
      expect(first == second).to be true
    end

    it 'returns false when the ids are different and there are no more attributes' do
      first = SDK::Event.new(:id => 'ev1')
      second = SDK::Event.new(:id => 'ev2')
      expect(first == second).to be false
    end

    it 'returns false when there are differences in other attributes' do
      first = SDK::Event.new(:id => 'ev1', :name => 'event1')
      second = SDK::Event.new(:id => 'ev1', :name => 'event2')
      expect(first == second).to be false
    end

    it 'returns true when there no differences in nested attributes' do
      first = SDK::Event.new(:id => '1', :vm => { :name => 'event1' })
      second = SDK::Event.new(:id => '1', :vm => { :name => 'event1' })
      expect(first == second).to be true
    end

    it 'returns false when there are differences in nested attributes' do
      first = SDK::Event.new(:id => 'ev1', :vm => { :name => 'event1' })
      second = SDK::Event.new(:id => 'ev1', :vm => { :name => 'event2' })
      expect(first == second).to be false
    end

    it 'returns true when there are no differences in nested arrays' do
      first = SDK::Event.new(
        :id => 'ev1',
        :vm => {
          :name => 'vm1',
          :disk_attachments => [
            SDK::DiskAttachment.new(:id => 'da1'),
            SDK::DiskAttachment.new(:id => 'da2'),
          ],
        }
      )
      second = SDK::Event.new(
        :id => 'ev1',
        :vm => {
          :name => 'vm1',
          :disk_attachments => [
            SDK::DiskAttachment.new(:id => 'da1'),
            SDK::DiskAttachment.new(:id => 'da2'),
          ],
        }
      )
      expect(first == second).to be true
    end

    it 'returns false when there are differences in nested arrays' do
      first = SDK::Event.new(
        :id => 'ev1',
        :vm => {
          :name => 'vm1',
          :disk_attachments => [
            SDK::DiskAttachment.new(:id => 'da1'),
            SDK::DiskAttachment.new(:id => 'da2'),
          ],
        }
      )
      second = SDK::Event.new(
        :id => 'ev1',
        :vm => {
          :name => 'vm1',
          :disk_attachments => [
            # The order is different, da2 and then da1, instead of da1 and then da2.
            SDK::DiskAttachment.new(:id => 'da2'),
            SDK::DiskAttachment.new(:id => 'da1'),
          ],
        }
      )
      expect(first == second).to be false
    end

    it 'returns true when comparing identical VM imports' do
      first = SDK::ExternalVmImport.new(
        :name           => 'oldname',
        :vm             => { :name => 'newname' },
        :provider       => SDK::ExternalVmProviderType::VMWARE,
        :username       => 'testuser',
        :password       => 'secret',
        :url            => 'foo',
        :cluster        => { :id => '2' },
        :storage_domain => { :id => '1' },
        :sparse         => true,
      )
      second = SDK::ExternalVmImport.new(
        :name           => 'oldname',
        :vm             => { :name => 'newname' },
        :provider       => SDK::ExternalVmProviderType::VMWARE,
        :username       => 'testuser',
        :password       => 'secret',
        :url            => 'foo',
        :cluster        => { :id => '2' },
        :storage_domain => { :id => '1' },
        :sparse         => true,
      )
      expect(first == second).to be true
    end

    it 'returns false when comparing different VM imports' do
      first = SDK::ExternalVmImport.new(
        :name           => 'oldname',
        :vm             => { :name => 'newname' },
        :provider       => SDK::ExternalVmProviderType::VMWARE,
        :username       => 'testuser',
        :password       => 'secret',
        :url            => 'foo',
        :cluster        => { :id => '2' },
        :storage_domain => { :id => '1' },
        :sparse         => true,
      )
      second = SDK::ExternalVmImport.new(
        :name           => 'oldname',
        :vm             => { :name => 'newname' },
        :provider       => SDK::ExternalVmProviderType::VMWARE,
        :username       => 'testuser',
        :password       => 'secret',
        :url            => 'foo',
        :cluster        => { :id => '3' }, # Id is 3 instead of 2.
        :storage_domain => { :id => '1' },
        :sparse         => true,
      )
      expect(first == second).to be false
    end
  end

end
