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

#include <ctype.h>
#include <stdbool.h>
#include <string.h>
#include <strings.h>

#include <libxml/xmlreader.h>

#include "ov_module.h"
#include "ov_error.h"
#include "ov_xml_reader.h"

// Symbols:
static VALUE IO_SYMBOL;

// Method identifiers:
static ID READ_ID;

typedef struct {
    VALUE io;
    xmlTextReaderPtr reader;
    bool closed;
} ov_xml_reader_object;

static void ov_xml_reader_check_closed(ov_xml_reader_object* object) {
    if (object->closed) {
        rb_raise(ov_error_class, "The reader is already closed");
    }
}

static void ov_xml_reader_mark(ov_xml_reader_object *object) {
    // Mark the IO object as reachable:
    if (!NIL_P(object->io)) {
        rb_gc_mark(object->io);
    }
}

static void ov_xml_reader_free(ov_xml_reader_object *object) {
    // Free the libxml reader:
    if (!object->closed) {
       xmlFreeTextReader(object->reader);
       object->reader = NULL;
       object->closed = true;
    }

    // Free this object:
    xfree(object);
}

static VALUE ov_xml_reader_alloc(VALUE klass) {
    ov_xml_reader_object *object = ALLOC(ov_xml_reader_object);
    return Data_Wrap_Struct(klass, ov_xml_reader_mark, ov_xml_reader_free, object);
}

static int ov_xml_reader_callback(void *context, char *buffer, int length) {
    ov_xml_reader_object *object = (ov_xml_reader_object*) context;

    // Do nothing if the reader is already closed:
    if (object->closed) {
        return -1;
    }

    // Read from the Ruby IO object, and copy the result to the buffer:
    VALUE data = rb_funcall(object->io, READ_ID, 1, INT2NUM(length));
    if (NIL_P(data)) {
        return 0;
    }
    length = RSTRING_LEN(data);
    memcpy(buffer, StringValuePtr(data), length);

    return length;
}

static VALUE ov_xml_reader_initialize(VALUE self, VALUE options) {
    // Initialize the reader:
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);

    // Get the options, and assign default values:
    Check_Type(options, T_HASH);
    VALUE io = rb_hash_aref(options, IO_SYMBOL);
    if (NIL_P(io)) {
       rb_raise(ov_error_class, "The \"io\" parameter is mandatory and can't be nil");
    }

    // Save the IO object:
    object->io = io;

    // Clear the closed flag:
    object->closed = false;

    // Create the libxml reader:
    object->reader = xmlReaderForIO(ov_xml_reader_callback, NULL, object, NULL, NULL, 0);
    if (object->reader == NULL) {
        rb_raise(ov_error_class, "Can't create reader");
    }

    // Move the cursor to the first node:
    int rc = xmlTextReaderRead(object->reader);
    if (rc == -1) {
        rb_raise(ov_error_class, "Can't read first node");
    }

    return self;
}

static VALUE ov_xml_reader_io(VALUE self) {
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);
    return object->io;
}

static VALUE ov_xml_reader_read(VALUE self) {
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    int rc = xmlTextReaderRead(object->reader);
    if (rc == 0) {
        return Qfalse;
    }
    if (rc == 1) {
        return Qtrue;
    }
    rb_raise(ov_error_class, "Can't move to next node");
    return Qnil;
}

static VALUE ov_xml_reader_node_type(VALUE self) {
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    int c_type = xmlTextReaderNodeType(object->reader);
    if (c_type == -1) {
        rb_raise(ov_error_class, "Can't get currrent node type");
        return Qnil;
    }
    VALUE type = INT2NUM(c_type);
    return type;
}

static VALUE ov_xml_reader_node_name(VALUE self) {
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    const xmlChar *c_name = xmlTextReaderConstName(object->reader);
    if (c_name == NULL) {
        return Qnil;
    }
    VALUE name = rb_str_new_cstr((char*) c_name);
    return name;
}

static VALUE ov_xml_reader_empty_element(VALUE self) {
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    return xmlTextReaderIsEmptyElement(object->reader)? Qtrue: Qfalse;
}

static VALUE ov_xml_reader_get_attribute(VALUE self, VALUE name) {
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    xmlChar *c_name = (xmlChar*) StringValueCStr(name);
    xmlChar *c_value = xmlTextReaderGetAttribute(object->reader, c_name);
    if (c_value == NULL) {
        return Qnil;
    }
    VALUE value = rb_str_new_cstr((char*) c_value);
    xmlFree(c_value);
    return value;
}

static VALUE ov_xml_reader_read_element(VALUE self) {
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    xmlChar *c_value = xmlTextReaderReadString(object->reader);
    if (c_value == NULL) {
        return Qnil;
    }
    VALUE value = rb_str_new_cstr((char*) c_value);
    xmlFree(c_value);
    return value;
}

static VALUE ov_xml_reader_next_element(VALUE self) {
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    int rc = xmlTextReaderNext(object->reader);
    if (rc == 0) {
        return Qfalse;
    }
    if (rc == 1) {
        return Qtrue;
    }
    rb_raise(ov_error_class, "Can't move to next element");
    return Qnil;
}

static VALUE ov_xml_reader_close(VALUE self) {
    ov_xml_reader_object *object;
    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    xmlFreeTextReader(object->reader);
    object->reader = NULL;
    object->closed = true;
    return Qnil;
}

void ov_xml_reader_define(void) {
    // Define the class:
    ov_xml_reader_class = rb_define_class_under(ov_module, "XmlReader", rb_cObject);

    // Define the constructor:
    rb_define_alloc_func(ov_xml_reader_class, ov_xml_reader_alloc);
    rb_define_method(ov_xml_reader_class, "initialize", ov_xml_reader_initialize, 1);

    // Define the methods:
    rb_define_method(ov_xml_reader_class, "io", ov_xml_reader_io, 0);
    rb_define_method(ov_xml_reader_class, "read", ov_xml_reader_read, 0);
    rb_define_method(ov_xml_reader_class, "node_type", ov_xml_reader_node_type, 0);
    rb_define_method(ov_xml_reader_class, "node_name", ov_xml_reader_node_name, 0);
    rb_define_method(ov_xml_reader_class, "empty_element?", ov_xml_reader_empty_element, 0);
    rb_define_method(ov_xml_reader_class, "get_attribute", ov_xml_reader_get_attribute, 1);
    rb_define_method(ov_xml_reader_class, "read_element", ov_xml_reader_read_element, 0);
    rb_define_method(ov_xml_reader_class, "next_element", ov_xml_reader_next_element, 0);
    rb_define_method(ov_xml_reader_class, "close", ov_xml_reader_close, 0);

    // Create symbols:
    IO_SYMBOL = ID2SYM(rb_intern("io"));

    // Create method identifiers:
    READ_ID = rb_intern("read");
}
