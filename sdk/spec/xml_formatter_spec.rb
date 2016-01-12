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

describe SDK::XmlFormatter do

  describe ".format_boolean" do

    context "given false" do

      it "returns 'false'" do
        result = SDK::XmlFormatter.format_boolean(false)
        expect(result).to eql('false')
      end

    end

    context "given true" do

      it "returns 'true'" do
        result = SDK::XmlFormatter.format_boolean(true)
        expect(result).to eql('true')
      end

    end

    context "given nil" do

      it "returns 'false'" do
        result = SDK::XmlFormatter.format_boolean(nil)
      end

    end

  end

end
