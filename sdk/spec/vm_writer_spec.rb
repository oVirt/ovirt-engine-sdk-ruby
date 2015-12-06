#
# Copyright (c) 2015 Red Hat, Inc.
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

require 'spec_helper'

describe SDK::VmWriter do

  describe ".write_one" do

    context "when empty" do

      it "writes the expected XML" do
        vm = SDK::Vm.new
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_one(vm, writer)
        writer.close
        expect(writer.io.string).to eql('<vm/>')
      end

    end

    context "when 'id' is set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:id => '123'})
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_one(vm, writer)
        writer.close
        expect(writer.io.string).to eql('<vm id="123"/>')
      end

    end

    context "when 'name' is set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:name => 'myvm'})
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_one(vm, writer)
        writer.close
        expect(writer.io.string).to eql('<vm><name>myvm</name></vm>')
      end

    end

    context "when 'name' and 'id' are set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:id => '123', :name => 'myvm'})
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_one(vm, writer)
        writer.close
        expect(writer.io.string).to eql('<vm id="123"><name>myvm</name></vm>')
      end

    end

    context "when boolean attribute is 'true'" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:delete_protected => true})
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_one(vm, writer)
        writer.close
        expect(writer.io.string).to eql('<vm><delete_protected>true</delete_protected></vm>')
      end

    end

    context "when boolean attribute is 'false'" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:delete_protected => false})
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_one(vm, writer)
        writer.close
        expect(writer.io.string).to eql('<vm><delete_protected>false</delete_protected></vm>')
      end

    end

    context "when 'cpu' is set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:cpu => {}})
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_one(vm, writer)
        writer.close
        expect(writer.io.string).to eql('<vm><cpu/></vm>')
      end

    end

    context "when 'cpu.name' is set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({
          :cpu => {:name => 'mycpu'}
        })
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_one(vm, writer)
        writer.close
        expect(writer.io.string).to eql('<vm><cpu><name>mycpu</name></cpu></vm>')
      end

    end

    context "when alternative element name is given" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:name => 'myvm'})
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_one(vm, writer, 'alternative')
        writer.close
        expect(writer.io.string).to eql('<alternative><name>myvm</name></alternative>')
      end

    end

  end

  describe ".write_many" do

    context "when empty" do

      it "writes the expected XML" do
        vms = []
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_many(vms, writer)
        writer.close
        expect(writer.io.string).to eql('<vms/>')
      end

    end

    context "when given one" do

      it "writes the expected XML" do
        vms = [
          SDK::Vm.new,
        ]
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_many(vms, writer)
        writer.close
        expect(writer.io.string).to eql('<vms><vm/></vms>')
      end

    end

    context "when given two" do

      it "writes the expected XML" do
        vms = [
          SDK::Vm.new,
          SDK::Vm.new,
        ]
        writer = SDK::XmlWriter.new({:io => StringIO.new})
        SDK::VmWriter.write_many(vms, writer)
        writer.close
        expect(writer.io.string).to eql('<vms><vm/><vm/></vms>')
      end

    end

  end

end
