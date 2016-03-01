/*
Copyright (c) 2015-2016 Red Hat, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include <ruby.h>

#include <libxml/xmlreader.h>

#include "ov_module.h"
#include "ov_xml_constants.h"

static void ov_xml_constants_define_integer(char *name, int value) {
    rb_define_const(ov_xml_constants_module, name, INT2NUM(value));
}

void ov_xml_constants_define(void) {
    // Define the module:
    ov_xml_constants_module = rb_define_module_under(ov_module, "XmlConstants");

    // Define the constants:
    ov_xml_constants_define_integer("TYPE_NONE", XML_READER_TYPE_NONE);
    ov_xml_constants_define_integer("TYPE_ELEMENT", XML_READER_TYPE_ELEMENT);
    ov_xml_constants_define_integer("TYPE_END_ELEMENT", XML_READER_TYPE_END_ELEMENT);
}
