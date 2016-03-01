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

require 'spec_helper'

describe SDK::Vm do

  describe ".disks=" do

    context "when given nil" do

      it "it is converted to nil" do
        vm = SDK::Vm.new
        vm.disks = nil
        expect(vm.disks).to be(nil)
      end

    end

    context "when given an array" do

      it "it is converted to a list" do
        vm = SDK::Vm.new
        vm.disks = []
        expect(vm.disks).to be_a(SDK::List)
      end

    end

  end

end
