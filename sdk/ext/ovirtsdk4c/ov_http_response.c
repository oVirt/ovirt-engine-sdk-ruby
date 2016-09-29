/*
Copyright (c) 2016 Red Hat, Inc.

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

#include "ov_module.h"
#include "ov_error.h"
#include "ov_http_response.h"

static VALUE BODY_SYMBOL;
static VALUE CODE_SYMBOL;
static VALUE HEADERS_SYMBOL;
static VALUE MESSAGE_SYMBOL;

static void ov_http_response_mark(ov_http_response_object *object) {
    if (!NIL_P(object->body)) {
        rb_gc_mark(object->body);
    }
    if (!NIL_P(object->code)) {
        rb_gc_mark(object->code);
    }
    if (!NIL_P(object->headers)) {
        rb_gc_mark(object->headers);
    }
    if (!NIL_P(object->message)) {
        rb_gc_mark(object->message);
    }
}

static void ov_http_response_free(ov_http_response_object *object) {
    xfree(object);
}

static VALUE ov_http_response_alloc(VALUE klass) {
    ov_http_response_object* object = NULL;

    object = ALLOC(ov_http_response_object);
    object->body = Qnil;
    object->code = Qnil;
    object->headers = Qnil;
    object->message = Qnil;
    return Data_Wrap_Struct(klass, ov_http_response_mark, ov_http_response_free, object);
}

static VALUE ov_http_response_get_body(VALUE self) {
    ov_http_response_object* object = NULL;

    Data_Get_Struct(self, ov_http_response_object, object);
    return object->body;
}

static VALUE ov_http_response_set_body(VALUE self, VALUE value) {
    ov_http_response_object* object = NULL;

    Data_Get_Struct(self, ov_http_response_object, object);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    object->body = value;
    return Qnil;
}

static VALUE ov_http_response_get_code(VALUE self) {
    ov_http_response_object* object = NULL;

    Data_Get_Struct(self, ov_http_response_object, object);
    return object->code;
}

static VALUE ov_http_response_set_code(VALUE self, VALUE value) {
    ov_http_response_object* object = NULL;

    Data_Get_Struct(self, ov_http_response_object, object);
    if (!NIL_P(value)) {
        Check_Type(value, T_FIXNUM);
    }
    object->code = value;
    return Qnil;
}

static VALUE ov_http_response_get_headers(VALUE self) {
    ov_http_response_object* object = NULL;

    Data_Get_Struct(self, ov_http_response_object, object);
    return object->headers;
}

static VALUE ov_http_response_set_headers(VALUE self, VALUE value) {
    ov_http_response_object* object = NULL;

    Data_Get_Struct(self, ov_http_response_object, object);
    if (NIL_P(value)) {
        object->headers = rb_hash_new();
    }
    else {
        Check_Type(value, T_HASH);
        object->headers = value;
    }
    return Qnil;
}

static VALUE ov_http_response_get_message(VALUE self) {
    ov_http_response_object* object = NULL;

    Data_Get_Struct(self, ov_http_response_object, object);
    return object->message;
}

static VALUE ov_http_response_set_message(VALUE self, VALUE value) {
    ov_http_response_object* object = NULL;

    Data_Get_Struct(self, ov_http_response_object, object);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    object->message = value;
    return Qnil;
}

static VALUE ov_http_response_initialize(int argc, VALUE* argv, VALUE self) {
    VALUE opts;

    /* Check the number of arguments: */
    if (argc > 1) {
      rb_raise(ov_error_class, "Expected at most one argument, 'opts', but received %d", argc);
    }
    opts = argc > 0? argv[0]: Qnil;
    if (NIL_P(opts)) {
        opts = rb_hash_new();
    }
    else {
        Check_Type(opts, T_HASH);
    }

    /* Get the values of the options: */
    ov_http_response_set_body(self, rb_hash_aref(opts, BODY_SYMBOL));
    ov_http_response_set_headers(self, rb_hash_aref(opts, HEADERS_SYMBOL));
    ov_http_response_set_code(self, rb_hash_aref(opts, CODE_SYMBOL));
    ov_http_response_set_message(self, rb_hash_aref(opts, MESSAGE_SYMBOL));

    return self;
}

void ov_http_response_define(void) {
    /* Define the class: */
    ov_http_response_class = rb_define_class_under(ov_module, "HttpResponse", rb_cObject);

    /* Define the constructor: */
    rb_define_alloc_func(ov_http_response_class, ov_http_response_alloc);
    rb_define_method(ov_http_response_class, "initialize", ov_http_response_initialize, -1);

    /* Define the methods: */
    rb_define_method(ov_http_response_class, "body",     ov_http_response_get_body,    0);
    rb_define_method(ov_http_response_class, "body=",    ov_http_response_set_body,    1);
    rb_define_method(ov_http_response_class, "code",     ov_http_response_get_code,    0);
    rb_define_method(ov_http_response_class, "code=",    ov_http_response_set_code,    1);
    rb_define_method(ov_http_response_class, "headers",  ov_http_response_get_headers, 0);
    rb_define_method(ov_http_response_class, "headers=", ov_http_response_set_headers, 1);
    rb_define_method(ov_http_response_class, "message",  ov_http_response_get_message, 0);
    rb_define_method(ov_http_response_class, "message=", ov_http_response_set_message, 1);

    /* Define the symbols: */
    BODY_SYMBOL    = ID2SYM(rb_intern("body"));
    CODE_SYMBOL    = ID2SYM(rb_intern("code"));
    HEADERS_SYMBOL = ID2SYM(rb_intern("headers"));
    MESSAGE_SYMBOL = ID2SYM(rb_intern("message"));
}
