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

describe SDK::Connection do

  describe ".build_url" do

    context "when given only the base" do

      it "builds the expected URL" do
        url = SDK::Connection.build_url({:base => default_url})
        expect(url).to eql(default_url)
      end

    end

    context "when given base and path" do

      it "builds the expected url" do
        url = SDK::Connection.build_url({:base => default_url, :path => "/vms"})
        expect(url).to eql(default_url + "/vms")
      end

    end

    context "when given base, path and query parameter" do

      it "builds the expected URL" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :query => {'max' => '10'},
        })
        expect(url).to eql(default_url + "/vms?max=10")
      end

    end

    context "when given base, path and multiple query parameters" do

      it "builds the expected URL" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :query => {'max' => '10', 'current' => 'true'},
        })
        expect(url).to eql(default_url + "/vms?max=10&current=true")
      end

    end

    context "when given base, path and matrix parameter" do

      it "builds the expected URL" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :matrix => {'max' => '10'},
        })
        expect(url).to eql(default_url + "/vms;max=10")
      end

    end

    context "when given base, path and multiple matrix parameters" do

      it "builds the expected URL" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :matrix => {'max' => '10', 'current' => 'true'},
        })
        expect(url).to eql(default_url + "/vms;max=10;current=true")
      end

    end

    context "when given base, path and both query and matrix parameters" do

      it "builds the expected URL" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :matrix => {'current' => 'true'},
          :query => {'max' => '10'},
        })
        expect(url).to eql(default_url + "/vms;current=true?max=10")
      end

    end

    context "when given a query parameter with white space in the value" do

      it "the white space is encoded correctly" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :query => {'search' => 'My VM'},
        })
        expect(url).to eql(default_url + "/vms?search=My+VM")
      end

    end

    context "when given a matrix parameter with white space in the value" do

      it "the white space is encoded correctly" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :matrix => {'search' => 'My VM'},
        })
        expect(url).to eql(default_url + "/vms;search=My+VM")
      end

    end

    context "when given a query parameter with an equals sign inside the value" do

      it "the equals sign is encoded correctly" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :query => {'search' => 'name=myvm'},
        })
        expect(url).to eql(default_url + "/vms?search=name%3Dmyvm")
      end

    end

    context "when given a matrix parameter with an equals sign inside the value" do

      it "the equals sign is encoded correctly" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :matrix => {'search' => 'name=myvm'},
        })
        expect(url).to eql(default_url + "/vms;search=name%3Dmyvm")
      end

    end

    context "when given an empty set of query parameters" do

      it "the set is ignored and not added to the URL" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :query => {},
        })
        expect(url).to eql(default_url + "/vms")
      end

    end

    context "when given an empty set of matrix parameters" do

      it "the set is ignored and not added to the URL" do
        url = SDK::Connection.build_url({
          :base => default_url,
          :path => "/vms",
          :matrix => {},
        })
        expect(url).to eql(default_url + "/vms")
      end

    end

  end

  describe ".new" do

    context "in secure mode", :integration => true do

      it "a exception is raised if no CA certificate is provided" do
        options = {
          :url => default_url,
          :username => default_user,
          :password => default_password,
        }
        expect { SDK::Connection.new(options) }.to raise_error(ArgumentError)
      end

      it "no exception is raised if a CA certificate is provided" do
        options = {
          :url => default_url,
          :username => default_user,
          :password => default_password,
          :ca_file => default_ca_file,
        }
        connection = SDK::Connection.new(options)
        connection.close
      end

    end

    context "in insecure mode", :integration => true do

      it "a CA certificate isn't required" do
        options = {
          :url => default_url,
          :username => default_user,
          :password => default_password,
          :insecure => true,
        }
        connection = SDK::Connection.new(options)
        connection.close
      end

    end

  end

  describe ".request" do

    context "GET of root", :integration => true do

      it "just works" do
        connection = SDK::Connection.new({
          :url => default_url,
          :username => default_user,
          :password => default_password,
          :ca_file => default_ca_file,
        })
        result = connection.request({
          :method => :GET,
          :path => "",
        })
        connection.close
      end

    end

  end

  describe ".service" do

    context "given nil", :integration => true do

      it "returns a reference to the system service" do
        connection = SDK::Connection.new({
          :url => default_url,
          :username => default_user,
          :password => default_password,
          :ca_file => default_ca_file,
        })
        result = connection.service(nil)
        expect(result).to be_a(SDK::SystemService)
        connection.close
      end

    end

    context "given empty string", :integration => true do

      it "returns a reference to the system service" do
        connection = SDK::Connection.new({
          :url => default_url,
          :username => default_user,
          :password => default_password,
          :ca_file => default_ca_file,
        })
        result = connection.service(nil)
        expect(result).to be_a(SDK::SystemService)
        connection.close
      end

    end

    context "given 'vms'", :integration => true do

      it "returns a reference to the virtual machines service" do
        connection = SDK::Connection.new({
          :url => default_url,
          :username => default_user,
          :password => default_password,
          :ca_file => default_ca_file,
        })
        result = connection.service('vms')
        expect(result).to be_a(SDK::VmsService)
        connection.close
      end

    end

    context "given 'vms/123'", :integration => true do

      it "returns a reference to the virtual machine service" do
        connection = SDK::Connection.new({
          :url => default_url,
          :username => default_user,
          :password => default_password,
          :ca_file => default_ca_file,
        })
        result = connection.service('vms/123')
        expect(result).to be_a(SDK::VmService)
        connection.close
      end

    end

    context "given 'vms/123/disks'", :integration => true do

      it "returns a reference to the virtual machine disks service" do
        connection = SDK::Connection.new({
          :url => default_url,
          :username => default_user,
          :password => default_password,
          :ca_file => default_ca_file,
        })
        result = connection.service('vms/123/disks')
        expect(result).to be_a(SDK::VmDisksService)
        connection.close
      end

    end

  end

end
