#!/usr/bin/ruby

#
# Copyright (c) 2015-2017 Red Hat, Inc.
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

require 'mkmf'

# Check if "libxml2" is available:
xml2_config = find_executable('xml2-config')
if xml2_config
  cflags = `#{xml2_config} --cflags`.strip
  libs = `#{xml2_config} --libs`.strip
  $CPPFLAGS = "#{cflags} #{$CPPFLAGS}"
  $LDFLAGS = "#{libs} #{$LDFLAGS}"
elsif !pkg_config('libxml2')
  raise 'The "libxml2" package isn\'t available.'
end

# Check if "libcurl" is available:
curl_config = find_executable('curl-config')
if curl_config
  cflags = `#{curl_config} --cflags`.strip
  libs = `#{curl_config} --libs`.strip
  $CPPFLAGS = "#{cflags} #{$CPPFLAGS}"
  $LDFLAGS = "#{libs} #{$LDFLAGS}"
elsif !pkg_config('libcurl')
  raise 'The "libcurl" package isn\'t available.'
end

# When installing the SDK as a plugin in Vagrant there is an issue with
# some versions of Vagrant that embed "libxml2" and "libcurl", but using
# an incorrect directory. To avoid that we need to explicitly fix the
# Vagrant path.
def fix_vagrant_prefix(flags)
  flags.gsub!('/vagrant-substrate/staging', '/opt/vagrant')
end
fix_vagrant_prefix($CPPFLAGS)
fix_vagrant_prefix($LDFLAGS)

# Create the Makefile:
create_makefile 'ovirtsdk4c'
