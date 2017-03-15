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

#include <ruby.h>

#include <libxml/xmlwriter.h>

#include "ov_module.h"
#include "ov_error.h"
#include "ov_xml_writer.h"

/* Class: */
VALUE ov_xml_writer_class;

/* Identifiers: */
static ID STRING_ID;
static ID STRING_IO_ID;
static ID WRITE_ID;

static void ov_xml_writer_check_closed(ov_xml_writer_object* ptr) {
    if (ptr->writer == NULL) {
        rb_raise(ov_error_class, "The writer is already closed");
    }
}

static void ov_xml_writer_mark(void* vptr) {
    ov_xml_writer_object* ptr;

    ptr = vptr;
    rb_gc_mark(ptr->io);
}

static void ov_xml_writer_free(void* vptr) {
    ov_xml_writer_object* ptr;

    /* Get the pointer: */
    ptr = vptr;

    /* Free the libxml writer, the buffer is automatically closed: */
    if (ptr->writer != NULL) {
        xmlTextWriterPtr tmp = ptr->writer;
        ptr->writer = NULL;
        xmlFreeTextWriter(tmp);
    }

    /* Free this object: */
    xfree(ptr);
}

rb_data_type_t ov_xml_writer_type = {
    .wrap_struct_name = "OVXMLWRITER",
    .function = {
        .dmark = ov_xml_writer_mark,
        .dfree = ov_xml_writer_free,
        .dsize = NULL,
        .reserved = { NULL, NULL }
    },
#ifdef RUBY_TYPED_FREE_IMMEDIATELY
    .parent = NULL,
    .data = NULL,
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
#endif
};

static VALUE ov_xml_writer_alloc(VALUE klass) {
    ov_xml_writer_object* ptr;

    ptr = ALLOC(ov_xml_writer_object);
    ptr->io = Qnil;
    ptr->writer = NULL;
    return TypedData_Wrap_Struct(klass, &ov_xml_writer_type, ptr);
}

static int ov_xml_writer_callback(void *context, const char *buffer, int length) {
    VALUE count;
    VALUE data;
    ov_xml_writer_object* ptr;

    /* Get the pointer: */
    ptr = context;

    /* Do nothing if the writer is already closed: */
    if (ptr->writer == NULL) {
        return 0;
    }

    /* Convert the buffer to a Ruby string and write it to the IO object, using the "write" method: */
    data = rb_str_new(buffer, length);
    count = rb_funcall(ptr->io, WRITE_ID, 1, data);

    return NUM2INT(count);
}

static VALUE ov_xml_writer_create_string_io() {
    VALUE sio_class;
    VALUE sio_obj;

    sio_class = rb_const_get(rb_cObject, STRING_IO_ID);
    sio_obj = rb_class_new_instance(0, NULL, sio_class);
    return sio_obj;
}

static VALUE ov_xml_writer_initialize(int argc, VALUE* argv, VALUE self) {
    VALUE indent;
    VALUE io;
    VALUE io_class;
    ov_xml_writer_object* ptr;
    xmlOutputBufferPtr buffer;

    /* Get the pointer to the object: */
    ov_xml_writer_ptr(self, ptr);

    /* Get the values of the parameters: */
    if (argc > 2) {
      rb_raise(ov_error_class, "Expected at most two arguments, 'io' and 'indent', but received %d", argc);
    }
    io = argc > 0? argv[0]: Qnil;
    indent = argc > 1? argv[1]: Qnil;

    /* The first parameter can be an IO object or nil. If it is nil then we need to create a IO object where we can
       write the generated XML. */
    if (NIL_P(io)) {
        ptr->io = ov_xml_writer_create_string_io();
    }
    else {
        io_class = rb_class_of(io);
        if (io_class == rb_cIO) {
            ptr->io = io;
        }
        else {
            rb_raise(
                ov_error_class,
                "The type of the 'io' parameter must be 'IO', but it is '%"PRIsVALUE"'",
                io_class
            );
        }
    }

    /* Create the libxml buffer that writes to the IO object: */
    buffer = xmlOutputBufferCreateIO(ov_xml_writer_callback, NULL, ptr, NULL);
    if (buffer == NULL) {
        rb_raise(ov_error_class, "Can't create XML buffer");
    }

    /* Create the libxml writer: */
    ptr->writer = xmlNewTextWriter(buffer);
    if (ptr->writer == NULL) {
        xmlOutputBufferClose(buffer);
        rb_raise(ov_error_class, "Can't create XML writer");
    }

    /* Enable indentation: */
    if (RTEST(indent)) {
        xmlTextWriterSetIndent(ptr->writer, 1);
        xmlTextWriterSetIndentString(ptr->writer, BAD_CAST "  ");
    }

    return self;
}

static VALUE ov_xml_writer_string(VALUE self) {
    int rc;
    ov_xml_writer_object* ptr;

    ov_xml_writer_ptr(self, ptr);
    ov_xml_writer_check_closed(ptr);
    rc = xmlTextWriterFlush(ptr->writer);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't flush XML writer");
    }
    return rb_funcall(ptr->io, STRING_ID, 0, NULL);
}

static VALUE ov_xml_writer_write_start(VALUE self, VALUE name) {
    char* c_name;
    int rc;
    ov_xml_writer_object* ptr;

    ov_xml_writer_ptr(self, ptr);
    ov_xml_writer_check_closed(ptr);
    Check_Type(name, T_STRING);
    c_name = StringValueCStr(name);
    rc = xmlTextWriterStartElement(ptr->writer, BAD_CAST c_name);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't start XML element");
    }
    return Qnil;
}

static VALUE ov_xml_writer_write_end(VALUE self) {
    int rc;
    ov_xml_writer_object* ptr;

    ov_xml_writer_ptr(self, ptr);
    ov_xml_writer_check_closed(ptr);
    rc = xmlTextWriterEndElement(ptr->writer);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't end XML element");
    }
    return Qnil;
}

static VALUE ov_xml_writer_write_attribute(VALUE self, VALUE name, VALUE value) {
    char* c_name;
    char* c_value;
    int rc;
    ov_xml_writer_object* ptr;

    ov_xml_writer_ptr(self, ptr);
    ov_xml_writer_check_closed(ptr);
    Check_Type(name, T_STRING);
    Check_Type(value, T_STRING);
    c_name = StringValueCStr(name);
    c_value = StringValueCStr(value);
    rc = xmlTextWriterWriteAttribute(ptr->writer, BAD_CAST c_name, BAD_CAST c_value);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't write attribute with name \"%s\" and value \"%s\"", c_name, c_value);
    }
    return Qnil;
}

static VALUE ov_xml_writer_write_element(VALUE self, VALUE name, VALUE value) {
    char* c_name;
    char* c_value;
    int rc;
    ov_xml_writer_object* ptr;

    ov_xml_writer_ptr(self, ptr);
    ov_xml_writer_check_closed(ptr);
    Check_Type(name, T_STRING);
    Check_Type(value, T_STRING);
    c_name = StringValueCStr(name);
    c_value = StringValueCStr(value);
    rc = xmlTextWriterWriteElement(ptr->writer, BAD_CAST c_name, BAD_CAST c_value);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't write element with name \"%s\" and value \"%s\"", c_name, c_value);
    }
    return Qnil;
}

static VALUE ov_xml_writer_flush(VALUE self) {
    int rc;
    ov_xml_writer_object* ptr;

    ov_xml_writer_ptr(self, ptr);
    ov_xml_writer_check_closed(ptr);
    rc = xmlTextWriterFlush(ptr->writer);
    if (rc < 0) {
        rb_raise(ov_error_class, "Can't flush XML writer");
    }
    return Qnil;
}

static VALUE ov_xml_writer_close(VALUE self) {
    ov_xml_writer_object* ptr;

    ov_xml_writer_ptr(self, ptr);
    ov_xml_writer_check_closed(ptr);
    xmlFreeTextWriter(ptr->writer);
    ptr->writer = NULL;
    return Qnil;
}

void ov_xml_writer_define(void) {
    /* Load required modules: */
    rb_require("stringio");

    /* Define the class: */
    ov_xml_writer_class = rb_define_class_under(ov_module, "XmlWriter", rb_cObject);

    /* Define the constructor: */
    rb_define_alloc_func(ov_xml_writer_class, ov_xml_writer_alloc);
    rb_define_method(ov_xml_writer_class, "initialize", ov_xml_writer_initialize, -1);

    /* Define the methods: */
    rb_define_method(ov_xml_writer_class, "close", ov_xml_writer_close, 0);
    rb_define_method(ov_xml_writer_class, "flush", ov_xml_writer_flush, 0);
    rb_define_method(ov_xml_writer_class, "string", ov_xml_writer_string, 0);
    rb_define_method(ov_xml_writer_class, "write_attribute", ov_xml_writer_write_attribute, 2);
    rb_define_method(ov_xml_writer_class, "write_element", ov_xml_writer_write_element, 2);
    rb_define_method(ov_xml_writer_class, "write_end", ov_xml_writer_write_end, 0);
    rb_define_method(ov_xml_writer_class, "write_start", ov_xml_writer_write_start, 1);

    /* Create method identifiers: */
    STRING_ID = rb_intern("string");
    STRING_IO_ID = rb_intern("StringIO");
    WRITE_ID = rb_intern("write");
}
