#
# Copyright (c) 2015 Red Hat, Inc.
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

require 'spec_helper'

describe SDK::VmWriter do

  describe ".write_one" do

    context "when empty" do

      it "writes the expected XML" do
        vm = SDK::Vm.new
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer)
        expect(writer.string).to eql('<vm/>')
        writer.close
      end

    end

    context "when 'id' is set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:id => '123'})
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer)
        expect(writer.string).to eql('<vm id="123"/>')
        writer.close
      end

    end

    context "when 'name' is set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:name => 'myvm'})
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer)
        expect(writer.string).to eql('<vm><name>myvm</name></vm>')
        writer.close
      end

    end

    context "when 'name' and 'id' are set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:id => '123', :name => 'myvm'})
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer)
        expect(writer.string).to eql('<vm id="123"><name>myvm</name></vm>')
        writer.close
      end

    end

    context "when boolean attribute is 'true'" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:delete_protected => true})
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer)
        expect(writer.string).to eql('<vm><delete_protected>true</delete_protected></vm>')
        writer.close
      end

    end

    context "when boolean attribute is 'false'" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:delete_protected => false})
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer)
        expect(writer.string).to eql('<vm><delete_protected>false</delete_protected></vm>')
        writer.close
      end

    end

    context "when 'cpu' is set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:cpu => {}})
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer)
        expect(writer.string).to eql('<vm><cpu/></vm>')
        writer.close
      end

    end

    context "when 'cpu.name' is set" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({
          :cpu => {:name => 'mycpu'}
        })
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer)
        expect(writer.string).to eql('<vm><cpu><name>mycpu</name></cpu></vm>')
        writer.close
      end

    end

    context "when alternative element name is given" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:name => 'myvm'})
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer, 'alternative')
        expect(writer.string).to eql('<alternative><name>myvm</name></alternative>')
        writer.close
      end

    end

    context "when the href attribute has a value" do

      it "writes the expected XML" do
        vm = SDK::Vm.new({:href => 'myhref'})
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_one(vm, writer)
        expect(writer.string).to eql('<vm href="myhref"/>')
        writer.close
      end

    end

  end

  describe ".write_many" do

    context "when empty array" do

      it "writes the expected XML" do
        vms = []
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_many(vms, writer)
        expect(writer.string).to eql('<vms/>')
        writer.close
      end

    end

    context "when empty list" do

      it "writes the expected XML" do
        vms = SDK::List[]
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_many(vms, writer)
        expect(writer.string).to eql('<vms/>')
        writer.close
      end

    end

    context "when given array with one element" do

      it "writes the expected XML" do
        vms = [
          SDK::Vm.new,
        ]
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_many(vms, writer)
        expect(writer.string).to eql('<vms><vm/></vms>')
        writer.close
      end

    end

    context "when given list with one element" do

      it "writes the expected XML" do
        vms = SDK::List[
          SDK::Vm.new,
        ]
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_many(vms, writer)
        expect(writer.string).to eql('<vms><vm/></vms>')
        writer.close
      end

    end

    context "when given array with two elements" do

      it "writes the expected XML" do
        vms = [
          SDK::Vm.new,
          SDK::Vm.new,
        ]
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_many(vms, writer)
        expect(writer.string).to eql('<vms><vm/><vm/></vms>')
        writer.close
      end

    end

    context "when given list with two elements" do

      it "writes the expected XML" do
        vms = SDK::List[
          SDK::Vm.new,
          SDK::Vm.new,
        ]
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_many(vms, writer)
        expect(writer.string).to eql('<vms><vm/><vm/></vms>')
        writer.close
      end

    end

    context "when the href attribute has a value" do

      it "writes the expected XML" do
        vms = SDK::List[
          SDK::Vm.new,
          SDK::Vm.new,
        ]
        vms.href = "myhref"
        writer = SDK::XmlWriter.new
        SDK::VmWriter.write_many(vms, writer)
        expect(writer.string).to eql('<vms href="myhref"><vm/><vm/></vms>')
        writer.close
      end

    end
  end

end
