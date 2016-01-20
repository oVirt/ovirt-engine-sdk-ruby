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

describe SDK::StorageDomainsService do

  before(:each) do
    @connection = default_connection
    @sds_service = @connection.system_service.storage_domains_service
  end

  after(:each) do
    @connection.close
  end

  describe ".data_centers", :integration => true do

    context "getting the reference to the service" do

      it "doesn't return nil" do
        expect(@sds_service).not_to be_nil
      end

    end

  end

  describe ".list", :integration => true do

    context "without parameters" do

      it "returns a list, maybe empty" do
        sds = @sds_service.list
        expect(sds).not_to be_nil
        expect(sds).to be_an(Array)
      end

    end

    context "with an unfeasible query" do

      it "returns an empty array" do
        sds = @sds_service.list({:search => 'name=ugly'})
        expect(sds).to eql([])
      end

    end

  end

end
