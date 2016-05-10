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

require 'spec_helper'

describe SDK::Connection do

  before(:all) do
    start_server
    set_xml_response('', 200, '<api/>')
  end

  after(:all) do
    stop_server
  end

  describe ".new" do

    context "in secure mode" do

      it "no exception is raised if no CA certificate is provided" do
        options = {
          :url => test_url,
          :username => test_user,
          :password => test_password,
        }
        connection = SDK::Connection.new(options)
        connection.close
      end

      it "no exception is raised if a CA certificate is provided" do
        options = {
          :url => test_url,
          :username => test_user,
          :password => test_password,
          :ca_file => test_ca_file,
        }
        connection = SDK::Connection.new(options)
        connection.close
      end

    end

    context "in insecure mode" do

      it "a CA certificate isn't required" do
        options = {
          :url => test_url,
          :username => test_user,
          :password => test_password,
          :insecure => true,
        }
        connection = SDK::Connection.new(options)
        connection.close
      end

    end

    context "given a log file that doesn't exist" do

      it "the file is created" do
        fd = Tempfile.new('log')
        log = fd.path
        fd.close
        fd.unlink
        options = {
          :url => test_url,
          :username => test_user,
          :password => test_password,
          :ca_file => test_ca_file,
          :debug => true,
          :log => log,
        }
        connection = SDK::Connection.new(options)
        connection.close
        expect(File.exists?(log)).to be true
        expect(File.size(log)).to be > 0
        File.delete(log)
      end

    end

    context "given a log IO object" do

      it "something is written to it" do
        log = Tempfile.new('log')
        options = {
          :url => test_url,
          :username => test_user,
          :password => test_password,
          :ca_file => test_ca_file,
          :debug => true,
          :log => log,
        }
        connection = SDK::Connection.new(options)
        connection.close
        expect(log.size).to be > 0
        log.close
        log.unlink
      end

    end

    context "with Kerberos enabled" do

      it "works correctly" do
        options = {
          :url => test_url,
          :kerberos => true,
          :ca_file => test_ca_file,
        }
        connection = SDK::Connection.new(options)
        connection.close
      end

    end

  end

end
