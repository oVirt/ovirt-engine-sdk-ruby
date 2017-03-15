/*
Copyright (c) 2015-2017 Red Hat, Inc.

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

#ifndef __OV_XML_WRITER_H__
#define __OV_XML_WRITER_H__

#include <ruby.h>

#include <libxml/xmlwriter.h>

/* Data type and class: */
extern rb_data_type_t ov_xml_writer_type;
extern VALUE ov_xml_writer_class;

/* Content: */
typedef struct {
    VALUE io;
    xmlTextWriterPtr writer;
} ov_xml_writer_object;

/* Macro to get the pointer: */
#define ov_xml_writer_ptr(object, ptr) \
    TypedData_Get_Struct((object), ov_xml_writer_object, &ov_xml_writer_type, (ptr))

/* Initialization function: */
extern void ov_xml_writer_define(void);

#endif
