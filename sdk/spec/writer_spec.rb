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

describe SDK::Writer do
  describe '.render_boolean' do
    context 'given false' do
      it 'returns "false"' do
        result = SDK::Writer.render_boolean(false)
        expect(result).to eql('false')
      end
    end

    context 'given true' do
      it 'returns "true"' do
        result = SDK::Writer.render_boolean(true)
        expect(result).to eql('true')
      end
    end

    context 'given nil' do
      it 'returns "false"' do
        SDK::Writer.render_boolean(nil)
      end
    end
  end

  describe '.write_string' do
    context 'given name and value' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_string(writer, 'value', 'myvalue')
        result = writer.string
        expect(result).to eql('<value>myvalue</value>')
      end
    end
  end

  describe '.write_boolean' do
    context 'given name and true' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_boolean(writer, 'value', true)
        result = writer.string
        expect(result).to eql('<value>true</value>')
      end
    end

    context 'given name and false' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_boolean(writer, 'value', false)
        expect(writer.string).to eql('<value>false</value>')
        writer.close
      end
    end

    context 'given name and truthy' do
      it 'writes "true"' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_boolean(writer, 'value', 'myvalue')
        expect(writer.string).to eql('<value>true</value>')
        writer.close
      end
    end

    context 'given name and falsy' do
      it 'writes "false"' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_boolean(writer, 'value', nil)
        expect(writer.string).to eql('<value>false</value>')
        writer.close
      end
    end
  end

  describe '.render_integer' do
    context 'given zero' do
      it 'writes the expected string' do
        expect(SDK::Writer.render_integer(0)).to eql('0')
      end
    end

    context 'given one' do
      it 'writes the expected string' do
        expect(SDK::Writer.render_integer(1)).to eql('1')
      end
    end

    context 'given minus one' do
      it 'writes the expected string' do
        expect(SDK::Writer.render_integer(-1)).to eql('-1')
      end
    end
  end

  describe '.write_integer' do
    context 'given zero' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_integer(writer, 'value', 0)
        expect(writer.string).to eql('<value>0</value>')
        writer.close
      end
    end

    context 'given one' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_integer(writer, 'value', 1)
        expect(writer.string).to eql('<value>1</value>')
        writer.close
      end
    end

    context 'given minus one' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_integer(writer, 'value', -1)
        expect(writer.string).to eql('<value>-1</value>')
        writer.close
      end
    end
  end

  describe '.render_decimal' do
    context 'given zero' do
      it 'writes the expected string' do
        expect(SDK::Writer.render_integer(0.0)).to eql('0.0')
      end
    end

    context 'given one' do
      it 'writes the expected string' do
        expect(SDK::Writer.render_integer(1.0)).to eql('1.0')
      end
    end

    context 'given minus one' do
      it 'writes the expected string' do
        expect(SDK::Writer.render_integer(-1.0)).to eql('-1.0')
      end
    end

    context 'given pi' do
      it 'writes the expected string' do
        expect(SDK::Writer.render_integer(3.1415)).to eql('3.1415')
      end
    end
  end

  describe '.write_decimal' do
    context 'given zero' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_integer(writer, 'value', 0.0)
        expect(writer.string).to eql('<value>0.0</value>')
        writer.close
      end
    end

    context 'given one' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_integer(writer, 'value', 1.0)
        expect(writer.string).to eql('<value>1.0</value>')
        writer.close
      end
    end

    context 'given minus one' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_integer(writer, 'value', -1.0)
        expect(writer.string).to eql('<value>-1.0</value>')
        writer.close
      end
    end

    context 'given pi' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        SDK::Writer.write_integer(writer, 'value', 3.1415)
        expect(writer.string).to eql('<value>3.1415</value>')
        writer.close
      end
    end
  end

  describe '.render_date' do
    context 'given a date' do
      it 'writes the expected string' do
        date = DateTime.new(2015, 12, 10, 22, 0, 30, '+1')
        expect(SDK::Writer.render_integer(date)).to eql('2015-12-10T22:00:30+01:00')
      end
    end
  end

  describe '.write_date' do
    context 'given a date' do
      it 'writes the expected XML' do
        writer = SDK::XmlWriter.new
        date = DateTime.new(2015, 12, 10, 22, 0, 30, '+1')
        SDK::Writer.write_date(writer, 'value', date)
        expect(writer.string).to eql('<value>2015-12-10T22:00:30+01:00</value>')
        writer.close
      end
    end
  end

  describe '.write' do
    it 'does not require an XML writer as parameter' do
      vm = SDK::Vm.new
      result = SDK::Writer.write(vm)
      expect(result).to eql('<vm/>')
    end

    it 'uses the alternative root tag if provided' do
      vm = SDK::Vm.new
      result = SDK::Writer.write(vm, root: 'list')
      expect(result).to eql('<list/>')
    end

    it 'accepts an XML writer as parameter' do
      vm = SDK::Vm.new
      writer = SDK::XmlWriter.new
      result = SDK::Writer.write(vm, target: writer)
      text = writer.string
      writer.close
      expect(result).to be_nil
      expect(text).to eql('<vm/>')
    end

    it 'raises an exception if given an array and no root tag' do
      expect { SDK::Writer.write([]) }.to raise_error(SDK::Error, /root.*mandatory/)
    end

    it 'accepts empty arrays' do
      result = SDK::Writer.write([], root: 'list')
      expect(result).to eql('<list/>')
    end

    it 'accepts arrays with one element' do
      vm = SDK::Vm.new
      result = SDK::Writer.write([vm], root: 'list')
      expect(result).to eql('<list><vm/></list>')
    end

    it 'accepts arrays with two elements' do
      vm = SDK::Vm.new
      result = SDK::Writer.write([vm, vm], root: 'list')
      expect(result).to eql('<list><vm/><vm/></list>')
    end

    it 'accepts arrays with elements of different types' do
      vm = SDK::Vm.new
      disk = SDK::Disk.new
      result = SDK::Writer.write([vm, disk], root: 'list')
      expect(result).to eql('<list><vm/><disk/></list>')
    end
  end
end
