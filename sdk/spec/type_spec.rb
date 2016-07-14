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

  describe '#dig' do

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

end
