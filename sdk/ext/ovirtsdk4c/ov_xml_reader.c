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

/* Class: */
VALUE ov_xml_reader_class;

// Method identifiers:
static ID READ_ID;
static ID STRING_IO_ID;

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
    /* Mark the IO object as reachable: */
    if (!NIL_P(object->io)) {
        rb_gc_mark(object->io);
    }
}

static void ov_xml_reader_free(ov_xml_reader_object *object) {
    /* Free the libxml reader: */
    if (!object->closed) {
       if (object->reader != NULL) {
           xmlFreeTextReader(object->reader);
       }
       object->reader = NULL;
       object->closed = true;
    }

    /* Free this object: */
    xfree(object);
}

static VALUE ov_xml_reader_alloc(VALUE klass) {
    ov_xml_reader_object* object = NULL;

    object = ALLOC(ov_xml_reader_object);
    memset(object, 0, sizeof(ov_xml_reader_object));
    return Data_Wrap_Struct(klass, ov_xml_reader_mark, ov_xml_reader_free, object);
}

static int ov_xml_reader_callback(void *context, char *buffer, int length) {
    VALUE data;
    ov_xml_reader_object* object = NULL;

    /* Do nothing if the reader is already closed: */
    object = (ov_xml_reader_object*) context;
    if (object->closed) {
        return -1;
    }

    /* Read from the Ruby IO object, and copy the result to the buffer: */
    data = rb_funcall(object->io, READ_ID, 1, INT2NUM(length));
    if (NIL_P(data)) {
        return 0;
    }
    length = RSTRING_LEN(data);
    memcpy(buffer, StringValuePtr(data), length);

    return length;
}

static VALUE ov_xml_reader_create_string_io(VALUE text) {
    VALUE sio_class;
    VALUE sio_obj;

    sio_class = rb_const_get(rb_cObject, STRING_IO_ID);
    sio_obj = rb_class_new_instance(1, &text, sio_class);
    return sio_obj;
}

static VALUE ov_xml_reader_initialize(VALUE self, VALUE io) {
    VALUE io_class;
    int rc = 0;
    ov_xml_reader_object* object = NULL;

    /* Get the pointer to the object: */
    Data_Get_Struct(self, ov_xml_reader_object, object);

    /* The parameter of the constructor can be a string or an IO object. If it is a string then we need to create aa
       IO object to read from it. */
    io_class = rb_class_of(io);
    if (io_class == rb_cString) {
        object->io = ov_xml_reader_create_string_io(io);
    }
    else if (io_class == rb_cIO) {
        object->io = io;
    }
    else {
        rb_raise(
            ov_error_class,
            "The type of the 'io' parameter must be 'String' or 'IO', but it is '%"PRIsVALUE"'",
            io_class
        );
    }

    /* Clear the closed flag: */
    object->closed = false;

    /* Create the libxml reader: */
    object->reader = xmlReaderForIO(ov_xml_reader_callback, NULL, object, NULL, NULL, 0);
    if (object->reader == NULL) {
        rb_raise(ov_error_class, "Can't create reader");
    }

    /* Move the cursor to the first node: */
    rc = xmlTextReaderRead(object->reader);
    if (rc == -1) {
        rb_raise(ov_error_class, "Can't read first node");
    }

    return self;
}

static VALUE ov_xml_reader_read(VALUE self) {
    int rc = 0;
    ov_xml_reader_object* object = NULL;

    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    rc = xmlTextReaderRead(object->reader);
    if (rc == 0) {
        return Qfalse;
    }
    if (rc == 1) {
        return Qtrue;
    }
    rb_raise(ov_error_class, "Can't move to next node");
    return Qnil;
}

static VALUE ov_xml_reader_forward(VALUE self) {
    int c_type = 0;
    int rc = 0;
    ov_xml_reader_object *object = NULL;

    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);

    for (;;) {
        c_type = xmlTextReaderNodeType(object->reader);
        if (c_type == -1) {
            rb_raise(ov_error_class, "Can't get current node type");
        }
        else if (c_type == XML_READER_TYPE_ELEMENT) {
            return Qtrue;
        }
        else if (c_type == XML_READER_TYPE_END_ELEMENT || c_type == XML_READER_TYPE_NONE) {
            return Qfalse;
        }
        else {
            rc = xmlTextReaderRead(object->reader);
            if (rc == -1) {
                rb_raise(ov_error_class, "Can't move to next node");
            }
        }
    }
}

static VALUE ov_xml_reader_node_name(VALUE self) {
    VALUE name;
    const xmlChar* c_name = NULL;
    ov_xml_reader_object* object = NULL;

    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    c_name = xmlTextReaderConstName(object->reader);
    if (c_name == NULL) {
        return Qnil;
    }
    name = rb_str_new_cstr((char*) c_name);
    return name;
}

static VALUE ov_xml_reader_empty_element(VALUE self) {
    ov_xml_reader_object* object = NULL;

    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    return xmlTextReaderIsEmptyElement(object->reader)? Qtrue: Qfalse;
}

static VALUE ov_xml_reader_get_attribute(VALUE self, VALUE name) {
    VALUE value;
    ov_xml_reader_object* object = NULL;
    xmlChar* c_name = NULL;
    xmlChar* c_value = NULL;

    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    c_name = (xmlChar*) StringValueCStr(name);
    c_value = xmlTextReaderGetAttribute(object->reader, c_name);
    if (c_value == NULL) {
        return Qnil;
    }
    value = rb_str_new_cstr((char*) c_value);
    xmlFree(c_value);
    return value;
}

static VALUE ov_xml_reader_read_element(VALUE self) {
    VALUE value;
    int c_empty = 0;
    int c_type = 0;
    int rc = 0;
    ov_xml_reader_object *object = NULL;
    xmlChar *c_value = NULL;

    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);

    /* Check the type of the current node: */
    c_type = xmlTextReaderNodeType(object->reader);
    if (c_type == -1) {
        rb_raise(ov_error_class, "Can't get current node type");
    }
    if (c_type != XML_READER_TYPE_ELEMENT) {
        rb_raise(ov_error_class, "Current node isn't the start of an element");
    }

    /* Check if the current node is empty: */
    c_empty = xmlTextReaderIsEmptyElement(object->reader);
    if (c_empty == -1) {
        rb_raise(ov_error_class, "Can't check if current element is empty");
    }

    /* For empty values elements there is no need to read the value. For non empty values we need to read the value, and
       check if it is NULL, as that means that the value is an empty string. */
    if (c_empty) {
        c_value = NULL;
    }
    else {
        c_value = xmlTextReaderReadString(object->reader);
        if (c_value == NULL) {
            c_value = xmlCharStrdup("");
            if (c_value == NULL) {
                rb_raise(ov_error_class, "Can't allocate XML string");
            }
        }
    }

    /* Move to the next element: */
    rc = xmlTextReaderNext(object->reader);
    if (rc == -1) {
        if (c_value != NULL) {
            xmlFree(c_value);
        }
        rb_raise(ov_error_class, "Can't move to the next element");
    }

    /* Return the result: */
    if (c_value == NULL) {
       return Qnil;
    }
    value = rb_str_new_cstr((char*) c_value);
    xmlFree(c_value);
    return value;
}

static VALUE ov_xml_reader_read_elements(VALUE self) {
    VALUE element;
    VALUE list;
    int c_type = 0;
    int rc = 0;
    ov_xml_reader_object* object = NULL;

    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    list = rb_ary_new();
    for (;;) {
        c_type = xmlTextReaderNodeType(object->reader);
        if (c_type == -1) {
            rb_raise(ov_error_class, "Can't get current node type");
        }
        else if (c_type == XML_READER_TYPE_ELEMENT) {
            element = ov_xml_reader_read_element(self);
            rb_ary_push(list, element);
        }
        else if (c_type == XML_READER_TYPE_END_ELEMENT || c_type == XML_READER_TYPE_NONE) {
            break;
        }
        else {
            rc = xmlTextReaderNext(object->reader);
            if (rc == -1) {
                rb_raise(ov_error_class, "Can't move to the next element");
            }
        }
    }
    return list;
}

static VALUE ov_xml_reader_next_element(VALUE self) {
    int rc = 0;
    ov_xml_reader_object* object = NULL;

    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    rc = xmlTextReaderNext(object->reader);
    if (rc == 0) {
        return Qfalse;
    }
    if (rc == 1) {
        return Qtrue;
    }
    rb_raise(ov_error_class, "Can't move to next element");
}

static VALUE ov_xml_reader_close(VALUE self) {
    ov_xml_reader_object* object = NULL;

    Data_Get_Struct(self, ov_xml_reader_object, object);
    ov_xml_reader_check_closed(object);
    xmlFreeTextReader(object->reader);
    object->reader = NULL;
    object->closed = true;
    return Qnil;
}

void ov_xml_reader_define(void) {
    /* Load required modules: */
    rb_require("stringio");

    /* Define the class: */
    ov_xml_reader_class = rb_define_class_under(ov_module, "XmlReader", rb_cObject);

    /* Define the constructor: */
    rb_define_alloc_func(ov_xml_reader_class, ov_xml_reader_alloc);
    rb_define_method(ov_xml_reader_class, "initialize", ov_xml_reader_initialize, 1);

    /* Define the methods: */
    rb_define_method(ov_xml_reader_class, "forward", ov_xml_reader_forward, 0);
    rb_define_method(ov_xml_reader_class, "read", ov_xml_reader_read, 0);
    rb_define_method(ov_xml_reader_class, "node_name", ov_xml_reader_node_name, 0);
    rb_define_method(ov_xml_reader_class, "empty_element?", ov_xml_reader_empty_element, 0);
    rb_define_method(ov_xml_reader_class, "get_attribute", ov_xml_reader_get_attribute, 1);
    rb_define_method(ov_xml_reader_class, "read_element", ov_xml_reader_read_element, 0);
    rb_define_method(ov_xml_reader_class, "read_elements", ov_xml_reader_read_elements, 0);
    rb_define_method(ov_xml_reader_class, "next_element", ov_xml_reader_next_element, 0);
    rb_define_method(ov_xml_reader_class, "close", ov_xml_reader_close, 0);

    /* Create method identifiers: */
    READ_ID = rb_intern("read");
    STRING_IO_ID = rb_intern("StringIO");
}
