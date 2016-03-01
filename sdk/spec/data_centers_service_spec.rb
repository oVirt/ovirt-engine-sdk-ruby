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

describe SDK::DataCentersService do

  before(:each) do
    @connection = default_connection
    @dcs_service = @connection.system_service.data_centers_service
  end

  after(:each) do
    @connection.close
  end

  describe ".data_centers", :integration => true do

    context "getting the reference to the service" do

      it "doesn't return nil" do
        expect(@dcs_service).not_to be_nil
      end

    end

  end

  describe ".list", :integration => true do

    context "without parameters" do

      it "returns a list, maybe empty" do
        dcs = @dcs_service.list
        expect(dcs).not_to be_nil
        expect(dcs).to be_an(Array)
      end

    end

    context "with an unfeasible query" do

      it "returns an empty array" do
        dcs = @dcs_service.list({:search => 'name=ugly'})
        expect(dcs).to eql([])
      end

    end

  end

end
