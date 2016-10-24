#--
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
#++

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib)
require 'ovirtsdk4/version'

Gem::Specification.new do |spec|

  # Basic information:
  spec.name        = 'ovirt-engine-sdk'
  spec.version     = OvirtSDK4::VERSION
  spec.summary     = 'oVirt SDK'
  spec.description = 'Ruby SDK for the oVirt Engine API.'
  spec.authors     = ['Juan Hernandez']
  spec.email       = ['jhernand@redhat.com']
  spec.license     = 'Apache-2.0'
  spec.homepage    = 'http://ovirt.org'

  # Ruby version:
  spec.required_ruby_version = '>= 1.9'

  # Build time dependencies:
  spec.add_development_dependency('rake', '~> 11.3')
  spec.add_development_dependency('rake-compiler', '~> 0.9')
  spec.add_development_dependency('rspec', '~> 3.3')
  spec.add_development_dependency('yard', '~> 0.8')

  # Run time dependencies:
  spec.add_dependency('json', '~> 1.8')

  # Extensions:
  spec.extensions = [
    'ext/ovirtsdk4c/extconf.rb',
  ]

  # Files:
  spec.files = Dir.glob([
    '.yardopts',
    'CHANGES.adoc',
    'LICENSE.txt',
    'README.adoc',
    'ext/**/*.{rb,c,h}',
    'lib/**/*.rb',
  ])

end
