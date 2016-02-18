/*
Copyright (c) 2015 Red Hat, Inc.
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

#include <stdbool.h>
#include <libxml/xmlwriter.h>

#include "ov_module.h"
#include "ov_error.h"
#include "ov_xml_writer.h"

// Symbols:
static VALUE IO_SYMBOL;
static VALUE INDENT_SYMBOL;

// Method identifiers:
static ID WRITE_ID;

typedef struct {
    VALUE io;
    xmlTextWriterPtr writer;
} ov_xml_writer_object;

static void ov_xml_writer_check_closed(ov_xml_writer_object* object) {
    if (object->writer == NULL) {
        rb_raise(ov_error_class, "The writer is already closed");
    }
}

static void ov_xml_writer_mark(ov_xml_writer_object *object) {
    // Mark the IO object as reachable:
    if (!NIL_P(object->io)) {
        rb_gc_mark(object->io);
    }
}

static void ov_xml_writer_free(ov_xml_writer_object *object) {
    // Free the libxml writer, the buffer is automatically closed:
    if (object->writer != NULL) {
        xmlTextWriterPtr tmp = object->writer;
        object->writer = NULL;
        xmlFreeTextWriter(tmp);
    }

    // Free this object:
    xfree(object);
}

static VALUE ov_xml_writer_alloc(VALUE klass) {
    ov_xml_writer_object *object = ALLOC(ov_xml_writer_object);
    return Data_Wrap_Struct(klass, ov_xml_writer_mark, ov_xml_writer_free, object);
}

static int ov_xml_writer_callback(void *context, const char *buffer, int length) {
    ov_xml_writer_object *object = (ov_xml_writer_object*) context;

    // Do nothing if the writer is already closed:
    if (object->writer == NULL) {
        return 0;
    }

    // Convert the buffer to a Ruby string and write it to the IO object, using the "write" method:
    VALUE data = rb_str_new(buffer, length);
    VALUE count = rb_funcall(object->io, WRITE_ID, 1, data);

    return NUM2INT(count);
}

static VALUE ov_xml_writer_initialize(VALUE self, VALUE options) {
    // Initialize the writer:
    ov_xml_writer_object *object;
    Data_Get_Struct(self, ov_xml_writer_object, object);

    // Get the options, and assign default values:
    Check_Type(options, T_HASH);
    VALUE io = rb_hash_aref(options, IO_SYMBOL);
    if (NIL_P(io)) {
       rb_raise(ov_error_class, "The \"io\" parameter is mandatory and can't be nil");
    }
    VALUE indent = rb_hash_aref(options, INDENT_SYMBOL);
    if (NIL_P(indent)) {
        indent = Qfalse;
    }

    // Save the IO object:
    object->io = io;

    // Create the libxml buffer that writes to the IO object:
    xmlOutputBufferPtr buffer = xmlOutputBufferCreateIO(ov_xml_writer_callback, NULL, object, NULL);
    if (buffer == NULL) {
        rb_raise(ov_error_class, "Can't create XML buffer");
    }

    // Create the libxml writer:
    object->writer = xmlNewTextWriter(buffer);
    if (object->writer == NULL) {
        xmlOutputBufferClose(buffer);
        rb_raise(ov_error_class, "Can't create XML writer");
    }

    // Enable indentation:
    if (RTEST(indent)) {
        xmlTextWriterSetIndent(object->writer, 1);
        xmlTextWriterSetIndentString(object->writer, BAD_CAST "  ");
    }

    return self;
}

static VALUE ov_xml_writer_io(VALUE self) {
    ov_xml_writer_object *object;
    Data_Get_Struct(self, ov_xml_writer_object, object);
    return object->io;
}

static VALUE ov_xml_writer_write_start(VALUE self, VALUE name) {
    ov_xml_writer_object *object;
    Data_Get_Struct(self, ov_xml_writer_object, object);
    ov_xml_writer_check_closed(object);
    Check_Type(name, T_STRING);
    char *c_name = StringValueCStr(name);
    int rc = xmlTextWriterStartElement(object->writer, BAD_CAST c_name);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't start XML element");
    }
    return Qnil;
}

static VALUE ov_xml_writer_write_end(VALUE self) {
    ov_xml_writer_object *object;
    Data_Get_Struct(self, ov_xml_writer_object, object);
    ov_xml_writer_check_closed(object);
    int rc = xmlTextWriterEndElement(object->writer);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't end XML element");
    }
    return Qnil;
}

static VALUE ov_xml_writer_write_attribute(VALUE self, VALUE name, VALUE value) {
    ov_xml_writer_object *object;
    Data_Get_Struct(self, ov_xml_writer_object, object);
    ov_xml_writer_check_closed(object);
    Check_Type(name, T_STRING);
    Check_Type(value, T_STRING);
    char *c_name = StringValueCStr(name);
    char *c_value = StringValueCStr(value);
    int rc = xmlTextWriterWriteAttribute(object->writer, BAD_CAST c_name, BAD_CAST c_value);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't write attribute with name \"%s\" and value \"%s\"", c_name, c_value);
    }
    return Qnil;
}

static VALUE ov_xml_writer_write_element(VALUE self, VALUE name, VALUE value) {
    ov_xml_writer_object *object;
    Data_Get_Struct(self, ov_xml_writer_object, object);
    ov_xml_writer_check_closed(object);
    Check_Type(name, T_STRING);
    Check_Type(value, T_STRING);
    char *c_name = StringValueCStr(name);
    char *c_value = StringValueCStr(value);
    int rc = xmlTextWriterWriteElement(object->writer, BAD_CAST c_name, BAD_CAST c_value);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't write element with name \"%s\" and value \"%s\"", c_name, c_value);
    }
    return Qnil;
}

static VALUE ov_xml_writer_flush(VALUE self) {
    ov_xml_writer_object *object;
    Data_Get_Struct(self, ov_xml_writer_object, object);
    ov_xml_writer_check_closed(object);
    int rc = xmlTextWriterFlush(object->writer);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't flush XML writer");
    }
    return Qnil;
}

static VALUE ov_xml_writer_close(VALUE self) {
    ov_xml_writer_object *object;
    Data_Get_Struct(self, ov_xml_writer_object, object);
    ov_xml_writer_check_closed(object);
    xmlFreeTextWriter(object->writer);
    object->writer = NULL;
    return Qnil;
}

void ov_xml_writer_define(void) {
    // Define the class:
    ov_xml_writer_class = rb_define_class_under(ov_module, "XmlWriter", rb_cObject);

    // Define the constructor:
    rb_define_alloc_func(ov_xml_writer_class, ov_xml_writer_alloc);
    rb_define_method(ov_xml_writer_class, "initialize", ov_xml_writer_initialize, 1);

    // Define the methods:
    rb_define_method(ov_xml_writer_class, "io", ov_xml_writer_io, 0);
    rb_define_method(ov_xml_writer_class, "write_start", ov_xml_writer_write_start, 1);
    rb_define_method(ov_xml_writer_class, "write_end", ov_xml_writer_write_end, 0);
    rb_define_method(ov_xml_writer_class, "write_attribute", ov_xml_writer_write_attribute, 2);
    rb_define_method(ov_xml_writer_class, "write_element", ov_xml_writer_write_element, 2);
    rb_define_method(ov_xml_writer_class, "flush", ov_xml_writer_flush, 0);
    rb_define_method(ov_xml_writer_class, "close", ov_xml_writer_close, 0);

    // Create symbols:
    IO_SYMBOL = ID2SYM(rb_intern("io"));
    INDENT_SYMBOL  = ID2SYM(rb_intern("indent"));

    // Create method identifiers:
    WRITE_ID = rb_intern("write");
}
