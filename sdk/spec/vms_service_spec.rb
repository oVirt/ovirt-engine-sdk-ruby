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

describe SDK::VmsService do

  before(:each) do
    @connection = default_connection
    @vms_service = @connection.system_service.vms_service
  end

  after(:each) do
    @connection.close
  end

  describe ".vms", :integration => true do

    context "getting the reference to the service" do

      it "doesn't return nil" do
        expect(@vms_service).not_to be_nil
      end

    end

  end

  describe ".list", :integration => true do

    context "without parameters" do

      it "returns a list, maybe empty" do
        vms = @vms_service.list
        expect(vms).not_to be_nil
        expect(vms).to be_an(Array)
      end

    end

    context "with an unfeasible query" do

      it "returns an empty array" do
        vms = @vms_service.list({:search => 'name=ugly'})
        expect(vms).to eql([])
      end

    end

  end

end
