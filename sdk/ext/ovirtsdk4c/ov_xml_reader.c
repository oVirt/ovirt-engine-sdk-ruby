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

/* Method identifiers: */
static ID READ_ID;
static ID STRING_IO_ID;

static void ov_xml_reader_check_closed(ov_xml_reader_object* ptr) {
    if (ptr->closed) {
        rb_raise(ov_error_class, "The reader is already closed");
    }
}

static void ov_xml_reader_mark(void* vptr) {
    ov_xml_reader_object* ptr;

    ptr = vptr;
    rb_gc_mark(ptr->io);
}

static void ov_xml_reader_free(void* vptr) {
    ov_xml_reader_object* ptr;

    /* Get the pointer: */
    ptr = vptr;

    /* Free the libxml reader: */
    if (!ptr->closed) {
       if (ptr->reader != NULL) {
           xmlFreeTextReader(ptr->reader);
       }
       ptr->reader = NULL;
       ptr->closed = true;
    }

    /* Free this object: */
    xfree(ptr);
}

rb_data_type_t ov_xml_reader_type = {
    .wrap_struct_name = "OVXMLREADER",
    .function = {
        .dmark = ov_xml_reader_mark,
        .dfree = ov_xml_reader_free,
        .dsize = NULL,
        .reserved = { NULL, NULL }
    },
#ifdef RUBY_TYPED_FREE_IMMEDIATELY
    .parent = NULL,
    .data = NULL,
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
#endif
};

static VALUE ov_xml_reader_alloc(VALUE klass) {
    ov_xml_reader_object* ptr;

    ptr = ALLOC(ov_xml_reader_object);
    ptr->io     = Qnil;
    ptr->reader = NULL;
    ptr->closed = false;
    return TypedData_Wrap_Struct(klass, &ov_xml_reader_type, ptr);
}

static int ov_xml_reader_callback(void *context, char *buffer, int length) {
    VALUE data;
    ov_xml_reader_object* ptr;

    /* Do nothing if the reader is already closed: */
    ptr = (ov_xml_reader_object*) context;
    if (ptr->closed) {
        return -1;
    }

    /* Read from the Ruby IO object, and copy the result to the buffer: */
    data = rb_funcall(ptr->io, READ_ID, 1, INT2NUM(length));
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
    int rc;
    ov_xml_reader_object* ptr;

    /* Get the pointer to the object: */
    ov_xml_reader_ptr(self, ptr);

    /* The parameter of the constructor can be a string or an IO object. If it is a string then we need to create aa
       IO object to read from it. */
    io_class = rb_class_of(io);
    if (io_class == rb_cString) {
        ptr->io = ov_xml_reader_create_string_io(io);
    }
    else if (io_class == rb_cIO) {
        ptr->io = io;
    }
    else {
        rb_raise(
            ov_error_class,
            "The type of the 'io' parameter must be 'String' or 'IO', but it is '%"PRIsVALUE"'",
            io_class
        );
    }

    /* Clear the closed flag: */
    ptr->closed = false;

    /* Create the libxml reader: */
    ptr->reader = xmlReaderForIO(ov_xml_reader_callback, NULL, ptr, NULL, NULL, 0);
    if (ptr->reader == NULL) {
        rb_raise(ov_error_class, "Can't create reader");
    }

    /* Move the cursor to the first node: */
    rc = xmlTextReaderRead(ptr->reader);
    if (rc == -1) {
        rb_raise(ov_error_class, "Can't read first node");
    }

    return self;
}

static VALUE ov_xml_reader_read(VALUE self) {
    int rc = 0;
    ov_xml_reader_object* ptr;

    ov_xml_reader_ptr(self, ptr);
    ov_xml_reader_check_closed(ptr);
    rc = xmlTextReaderRead(ptr->reader);
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
    ov_xml_reader_object* ptr;

    ov_xml_reader_ptr(self, ptr);
    ov_xml_reader_check_closed(ptr);

    for (;;) {
        c_type = xmlTextReaderNodeType(ptr->reader);
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
            rc = xmlTextReaderRead(ptr->reader);
            if (rc == -1) {
                rb_raise(ov_error_class, "Can't move to next node");
            }
        }
    }
}

static VALUE ov_xml_reader_node_name(VALUE self) {
    VALUE name;
    const xmlChar* c_name;
    ov_xml_reader_object* ptr;

    ov_xml_reader_ptr(self, ptr);
    ov_xml_reader_check_closed(ptr);
    c_name = xmlTextReaderConstName(ptr->reader);
    if (c_name == NULL) {
        return Qnil;
    }
    name = rb_str_new_cstr((char*) c_name);
    return name;
}

static VALUE ov_xml_reader_empty_element(VALUE self) {
    int c_empty;
    ov_xml_reader_object* ptr;

    ov_xml_reader_ptr(self, ptr);
    ov_xml_reader_check_closed(ptr);
    c_empty = xmlTextReaderIsEmptyElement(ptr->reader);
    if (c_empty == -1) {
        rb_raise(ov_error_class, "Can't check if current element is empty");
    }
    return c_empty? Qtrue: Qfalse;
}

static VALUE ov_xml_reader_get_attribute(VALUE self, VALUE name) {
    VALUE value;
    ov_xml_reader_object* ptr;
    xmlChar* c_name;
    xmlChar* c_value;

    ov_xml_reader_ptr(self, ptr);
    ov_xml_reader_check_closed(ptr);
    c_name = (xmlChar*) StringValueCStr(name);
    c_value = xmlTextReaderGetAttribute(ptr->reader, c_name);
    if (c_value == NULL) {
        return Qnil;
    }
    value = rb_str_new_cstr((char*) c_value);
    xmlFree(c_value);
    return value;
}

static VALUE ov_xml_reader_read_element(VALUE self) {
    VALUE value;
    int c_empty;
    int c_type;
    int rc;
    ov_xml_reader_object* ptr;
    xmlChar* c_value;

    ov_xml_reader_ptr(self, ptr);
    ov_xml_reader_check_closed(ptr);

    /* Check the type of the current node: */
    c_type = xmlTextReaderNodeType(ptr->reader);
    if (c_type == -1) {
        rb_raise(ov_error_class, "Can't get current node type");
    }
    if (c_type != XML_READER_TYPE_ELEMENT) {
        rb_raise(ov_error_class, "Current node isn't the start of an element");
    }

    /* Check if the current node is empty: */
    c_empty = xmlTextReaderIsEmptyElement(ptr->reader);
    if (c_empty == -1) {
        rb_raise(ov_error_class, "Can't check if current element is empty");
    }

    /* For empty values elements there is no need to read the value. For non empty values we need to read the value, and
       check if it is NULL, as that means that the value is an empty string. */
    if (c_empty) {
        c_value = NULL;
    }
    else {
        c_value = xmlTextReaderReadString(ptr->reader);
        if (c_value == NULL) {
            c_value = xmlCharStrdup("");
            if (c_value == NULL) {
                rb_raise(ov_error_class, "Can't allocate XML string");
            }
        }
    }

    /* Move to the next element: */
    rc = xmlTextReaderNext(ptr->reader);
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
    int c_empty;
    int c_type;
    int rc;
    ov_xml_reader_object* ptr;

    /* Get the pointer to the object and check that it isn't closed: */
    ov_xml_reader_ptr(self, ptr);
    ov_xml_reader_check_closed(ptr);

    /* This method assumes that the reader is positioned at the element that contains the values to read. For example
       if the XML document is the following:

       <list>
         <value>first</value>
         <value>second</value>
       </list>

       The reader should be positioned at the <list> element. The first thing we need to do is to check: */
    c_type = xmlTextReaderNodeType(ptr->reader);
    if (c_type == -1) {
        rb_raise(ov_error_class, "Can't get current node type");
    }
    if (c_type != XML_READER_TYPE_ELEMENT) {
        rb_raise(ov_error_class, "Current node isn't the start of an element");
    }

    /* If we are indeed positioned at the first element, then we need to check if it is empty, <list/>, as we will
       need this lter, after discarding the element: */
    c_empty = xmlTextReaderIsEmptyElement(ptr->reader);
    if (c_empty == -1) {
        rb_raise(ov_error_class, "Can't check if current element is empty");
    }

    /* Now we need to discard the current element, as we are interested only in the nested <value>...</value>
       elements: */
    rc = xmlTextReaderRead(ptr->reader);
    if (rc == -1) {
        rb_raise(ov_error_class, "Can't move to next node");
    }

    /* Create the list that will contain the result: */
    list = rb_ary_new();

    /* At this point, if the start element was empty, we don't need to do anything else: */
    if (c_empty) {
        return list;
    }

    /* Process the nested elements: */
    for (;;) {
        c_type = xmlTextReaderNodeType(ptr->reader);
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
            rc = xmlTextReaderNext(ptr->reader);
            if (rc == -1) {
                rb_raise(ov_error_class, "Can't move to the next node");
            }
        }
    }

    /* Once all the nested <value>...</value> elements are processed the reader will be positioned at the closing
       </list> element, or at the end of the document. If it is the closing element then we need to discard it. */
    if (c_type == XML_READER_TYPE_END_ELEMENT) {
        rc = xmlTextReaderRead(ptr->reader);
        if (rc == -1) {
            rb_raise(ov_error_class, "Can't move to next node");
        }
    }

    return list;
}

static VALUE ov_xml_reader_next_element(VALUE self) {
    int rc;
    ov_xml_reader_object* ptr;

    ov_xml_reader_ptr(self, ptr);
    ov_xml_reader_check_closed(ptr);
    rc = xmlTextReaderNext(ptr->reader);
    if (rc == 0) {
        return Qfalse;
    }
    if (rc == 1) {
        return Qtrue;
    }
    rb_raise(ov_error_class, "Can't move to next element");
}

static VALUE ov_xml_reader_close(VALUE self) {
    ov_xml_reader_object* ptr;

    ov_xml_reader_ptr(self, ptr);
    ov_xml_reader_check_closed(ptr);
    xmlFreeTextReader(ptr->reader);
    ptr->reader = NULL;
    ptr->closed = true;
    return Qnil;
}

void ov_xml_reader_define(void) {
    /* Load required modules: */
    rb_require("stringio");

    /* Define the class: */
    ov_xml_reader_class = rb_define_class_under(ov_module, "XmlReader", rb_cData);

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
