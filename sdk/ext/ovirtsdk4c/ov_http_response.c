/*
Copyright (c) 2016-2017 Red Hat, Inc.

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

/* The class: */
VALUE ov_http_response_class;

static VALUE BODY_SYMBOL;
static VALUE CODE_SYMBOL;
static VALUE HEADERS_SYMBOL;
static VALUE MESSAGE_SYMBOL;

static void ov_http_response_mark(void* vptr) {
    ov_http_response_object* ptr;

    ptr = vptr;
    rb_gc_mark(ptr->body);
    rb_gc_mark(ptr->code);
    rb_gc_mark(ptr->headers);
    rb_gc_mark(ptr->message);
}

static void ov_http_response_free(void* vptr) {
    ov_http_response_object* ptr;

    ptr = vptr;
    xfree(ptr);
}

rb_data_type_t ov_http_response_type = {
    .wrap_struct_name = "OVHTTPRESPONSE",
    .function = {
        .dmark = ov_http_response_mark,
        .dfree = ov_http_response_free,
        .dsize = NULL,
        .reserved = { NULL, NULL }
    },
#ifdef RUBY_TYPED_FREE_IMMEDIATELY
    .parent = NULL,
    .data = NULL,
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
#endif
};

static VALUE ov_http_response_alloc(VALUE klass) {
    ov_http_response_object* ptr;

    ptr = ALLOC(ov_http_response_object);
    ptr->body = Qnil;
    ptr->code = Qnil;
    ptr->headers = Qnil;
    ptr->message = Qnil;
    return TypedData_Wrap_Struct(klass, &ov_http_response_type, ptr);
}

static VALUE ov_http_response_get_body(VALUE self) {
    ov_http_response_object* ptr;

    ov_http_response_ptr(self, ptr);
    return ptr->body;
}

static VALUE ov_http_response_set_body(VALUE self, VALUE value) {
    ov_http_response_object* ptr;

    ov_http_response_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    ptr->body = value;
    return Qnil;
}

static VALUE ov_http_response_get_code(VALUE self) {
    ov_http_response_object* ptr;

    ov_http_response_ptr(self, ptr);
    return ptr->code;
}

static VALUE ov_http_response_set_code(VALUE self, VALUE value) {
    ov_http_response_object* ptr;

    ov_http_response_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_FIXNUM);
    }
    ptr->code = value;
    return Qnil;
}

static VALUE ov_http_response_get_headers(VALUE self) {
    ov_http_response_object* ptr;

    ov_http_response_ptr(self, ptr);
    return ptr->headers;
}

static VALUE ov_http_response_set_headers(VALUE self, VALUE value) {
    ov_http_response_object* ptr;

    ov_http_response_ptr(self, ptr);
    if (NIL_P(value)) {
        ptr->headers = rb_hash_new();
    }
    else {
        Check_Type(value, T_HASH);
        ptr->headers = value;
    }
    return Qnil;
}

static VALUE ov_http_response_get_message(VALUE self) {
    ov_http_response_object* ptr;

    ov_http_response_ptr(self, ptr);
    return ptr->message;
}

static VALUE ov_http_response_set_message(VALUE self, VALUE value) {
    ov_http_response_object* ptr;

    ov_http_response_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    ptr->message = value;
    return Qnil;
}

static VALUE ov_http_response_inspect(VALUE self) {
    ov_http_response_object* ptr;

    ov_http_response_ptr(self, ptr);
    return rb_sprintf(
        "#<%"PRIsVALUE":%"PRIsVALUE" %"PRIsVALUE">",
        ov_http_response_class,
        ptr->code,
        ptr->message
    );
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
    ov_http_response_class = rb_define_class_under(ov_module, "HttpResponse", rb_cData);

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
    rb_define_method(ov_http_response_class, "inspect",  ov_http_response_inspect,     0);
    rb_define_method(ov_http_response_class, "to_s",     ov_http_response_inspect,     0);

    /* Define the symbols: */
    BODY_SYMBOL    = ID2SYM(rb_intern("body"));
    CODE_SYMBOL    = ID2SYM(rb_intern("code"));
    HEADERS_SYMBOL = ID2SYM(rb_intern("headers"));
    MESSAGE_SYMBOL = ID2SYM(rb_intern("message"));
}
