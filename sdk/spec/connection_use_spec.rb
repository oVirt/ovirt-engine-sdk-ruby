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

describe SDK::Connection do

  before(:all) do
    start_server
    @connection = test_connection
  end

  after(:all) do
    @connection.close
    stop_server
  end

  describe ".build_url" do

    context "when given only the base" do

      it "builds the expected URL" do
        url = @connection.build_url
        expect(url).to eql(test_url)
      end

    end

    context "when given base and path" do

      it "builds the expected url" do
        url = @connection.build_url(:path => "/vms")
        expect(url).to eql(test_url + "/vms")
      end

    end

    context "when given base, path and query parameter" do

      it "builds the expected URL" do
        url = @connection.build_url(
          :path => "/vms",
          :query => {'max' => '10'},
        )
        expect(url).to eql(test_url + "/vms?max=10")
      end

    end

    context "when given base, path and multiple query parameters" do

      it "builds the expected URL" do
        url = @connection.build_url(
          :path => "/vms",
          :query => {'max' => '10', 'current' => 'true'},
        )
        expect(url).to eql(test_url + "/vms?max=10&current=true")
      end

    end

    context "when given a query parameter with white space in the value" do

      it "the white space is encoded correctly" do
        url = @connection.build_url(
          :path => "/vms",
          :query => {'search' => 'My VM'},
        )
        expect(url).to eql(test_url + "/vms?search=My+VM")
      end

    end

    context "when given a query parameter with an equals sign inside the value" do

      it "the equals sign is encoded correctly" do
        url = @connection.build_url(
          :path => "/vms",
          :query => {'search' => 'name=myvm'},
        )
        expect(url).to eql(test_url + "/vms?search=name%3Dmyvm")
      end

    end

    context "when given an empty set of query parameters" do

      it "the set is ignored and not added to the URL" do
        url = @connection.build_url(
          :path => "/vms",
          :query => {},
        )
        expect(url).to eql(test_url + "/vms")
      end

    end

  end

  describe ".url" do

    context "when the connection is created" do

      it "the URL can be obtained" do
        expect(@connection.url.to_s).to eql(test_url)
      end

    end

  end

  describe ".send" do

    context "GET of root" do

      it "just works" do
        set_xml_response('', 200, '<api/>')
        request = SDK::Request.new
        response = @connection.send(request)
        expect(response.code).to eql(200)
      end

    end

  end

  describe ".service" do

    context "given nil" do

      it "returns a reference to the system service" do
        result = @connection.service(nil)
        expect(result).to be_a(SDK::SystemService)
      end

    end

    context "given empty string" do

      it "returns a reference to the system service" do
        result = @connection.service(nil)
        expect(result).to be_a(SDK::SystemService)
      end

    end

    context "given 'vms'" do

      it "returns a reference to the virtual machines service" do
        result = @connection.service('vms')
        expect(result).to be_a(SDK::VmsService)
      end

    end

    context "given 'vms/123'" do

      it "returns a reference to the virtual machine service" do
        result = @connection.service('vms/123')
        expect(result).to be_a(SDK::VmService)
      end

    end

    context "given 'vms/123/diskattachments'" => true do

      it "returns a reference to the virtual machine disk attachments service" do
        result = @connection.service('vms/123/diskattachments')
        expect(result).to be_a(SDK::DiskAttachmentsService)
      end

    end

  end

end
