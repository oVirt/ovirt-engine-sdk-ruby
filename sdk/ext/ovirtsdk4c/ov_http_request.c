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
#include "ov_http_request.h"

/* Class: */
VALUE ov_http_request_class;

/* Symbols for HTTP methods: */
VALUE GET_SYMBOL;
VALUE POST_SYMBOL;
VALUE PUT_SYMBOL;
VALUE DELETE_SYMBOL;

/* Symbols for the attributes: */
static VALUE METHOD_SYMBOL;
static VALUE URL_SYMBOL;
static VALUE QUERY_SYMBOL;
static VALUE HEADERS_SYMBOL;
static VALUE USERNAME_SYMBOL;
static VALUE PASSWORD_SYMBOL;
static VALUE TOKEN_SYMBOL;
static VALUE KERBEROS_SYMBOL;
static VALUE BODY_SYMBOL;
static VALUE TIMEOUT_SYMBOL;
static VALUE CONNECT_TIMEOUT_SYMBOL;

static void ov_http_request_mark(void* vptr) {
    ov_http_request_object* ptr;

    ptr = vptr;
    rb_gc_mark(ptr->method);
    rb_gc_mark(ptr->url);
    rb_gc_mark(ptr->query);
    rb_gc_mark(ptr->headers);
    rb_gc_mark(ptr->username);
    rb_gc_mark(ptr->password);
    rb_gc_mark(ptr->token);
    rb_gc_mark(ptr->kerberos);
    rb_gc_mark(ptr->body);
    rb_gc_mark(ptr->timeout);
    rb_gc_mark(ptr->connect_timeout);
}

static void ov_http_request_free(void* vptr) {
    ov_http_request_object* ptr;

    ptr = vptr;
    xfree(ptr);
}

rb_data_type_t ov_http_request_type = {
    .wrap_struct_name = "OVHTTPREQUEST",
    .function = {
        .dmark = ov_http_request_mark,
        .dfree = ov_http_request_free,
        .dsize = NULL,
        .reserved = { NULL, NULL }
    },
#ifdef RUBY_TYPED_FREE_IMMEDIATELY
    .parent = NULL,
    .data = NULL,
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
#endif
};

static VALUE ov_http_request_alloc(VALUE klass) {
    ov_http_request_object* ptr;

    ptr = ALLOC(ov_http_request_object);
    ptr->method          = Qnil;
    ptr->url             = Qnil;
    ptr->query           = Qnil;
    ptr->headers         = Qnil;
    ptr->username        = Qnil;
    ptr->password        = Qnil;
    ptr->token           = Qnil;
    ptr->kerberos        = Qnil;
    ptr->body            = Qnil;
    ptr->timeout         = Qnil;
    ptr->connect_timeout = Qnil;
    return TypedData_Wrap_Struct(klass, &ov_http_request_type, ptr);
}

static VALUE ov_http_request_get_method(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->method;
}

static VALUE ov_http_request_set_method(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (NIL_P(value)) {
        ptr->method = GET_SYMBOL;
    }
    else {
        Check_Type(value, T_SYMBOL);
        ptr->method = value;
    }
    return Qnil;
}

static VALUE ov_http_request_get_url(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->url;
}

static VALUE ov_http_request_set_url(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    ptr->url = value;
    return Qnil;
}

static VALUE ov_http_request_get_query(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->query;
}

static VALUE ov_http_request_set_query(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_HASH);
    }
    ptr->query = value;
    return Qnil;
}

static VALUE ov_http_request_get_headers(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->headers;
}

static VALUE ov_http_request_set_headers(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (NIL_P(value)) {
        ptr->headers = rb_hash_new();
    }
    else {
        Check_Type(value, T_HASH);
        ptr->headers = value;
    }
    return Qnil;
}

static VALUE ov_http_request_get_username(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->username;
}

static VALUE ov_http_request_set_username(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    ptr->username = value;
    return Qnil;
}

static VALUE ov_http_request_get_password(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->password;
}

static VALUE ov_http_request_set_password(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    ptr->password = value;
    return Qnil;
}

static VALUE ov_http_request_get_token(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->token;
}

static VALUE ov_http_request_set_token(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    ptr->token = value;
    return Qnil;
}

static VALUE ov_http_request_get_kerberos(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->kerberos;
}

static VALUE ov_http_request_set_kerberos(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    ptr->kerberos = RTEST(value);
    return Qnil;
}

static VALUE ov_http_request_get_body(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->body;
}

static VALUE ov_http_request_set_body(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    ptr->body = value;
    return Qnil;
}

static VALUE ov_http_request_get_timeout(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->timeout;
}

static VALUE ov_http_request_set_timeout(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_FIXNUM);
    }
    ptr->timeout = value;
    return Qnil;
}

static VALUE ov_http_request_get_connect_timeout(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return ptr->connect_timeout;
}

static VALUE ov_http_request_set_connect_timeout(VALUE self, VALUE value) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    if (!NIL_P(value)) {
        Check_Type(value, T_FIXNUM);
    }
    ptr->connect_timeout = value;
    return Qnil;
}

static VALUE ov_http_request_inspect(VALUE self) {
    ov_http_request_object* ptr;

    ov_http_request_ptr(self, ptr);
    return rb_sprintf(
        "#<%"PRIsVALUE":%"PRIsVALUE" %"PRIsVALUE">",
        ov_http_request_class,
        ptr->method,
        ptr->url
    );
}

static VALUE ov_http_request_initialize(int argc, VALUE* argv, VALUE self) {
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
    ov_http_request_set_method(self, rb_hash_aref(opts, METHOD_SYMBOL));
    ov_http_request_set_url(self, rb_hash_aref(opts, URL_SYMBOL));
    ov_http_request_set_query(self, rb_hash_aref(opts, QUERY_SYMBOL));
    ov_http_request_set_headers(self, rb_hash_aref(opts, HEADERS_SYMBOL));
    ov_http_request_set_username(self, rb_hash_aref(opts, USERNAME_SYMBOL));
    ov_http_request_set_password(self, rb_hash_aref(opts, PASSWORD_SYMBOL));
    ov_http_request_set_token(self, rb_hash_aref(opts, TOKEN_SYMBOL));
    ov_http_request_set_body(self, rb_hash_aref(opts, BODY_SYMBOL));
    ov_http_request_set_timeout(self, rb_hash_aref(opts, TIMEOUT_SYMBOL));
    ov_http_request_set_connect_timeout(self, rb_hash_aref(opts, CONNECT_TIMEOUT_SYMBOL));

    return self;
}

void ov_http_request_define(void) {
    /* Define the class: */
    ov_http_request_class = rb_define_class_under(ov_module, "HttpRequest", rb_cData);

    /* Define the constructor: */
    rb_define_alloc_func(ov_http_request_class, ov_http_request_alloc);
    rb_define_method(ov_http_request_class, "initialize", ov_http_request_initialize, -1);

    /* Define the methods: */
    rb_define_method(ov_http_request_class, "method",           ov_http_request_get_method,          0);
    rb_define_method(ov_http_request_class, "method=",          ov_http_request_set_method,          1);
    rb_define_method(ov_http_request_class, "url",              ov_http_request_get_url,             0);
    rb_define_method(ov_http_request_class, "url=",             ov_http_request_set_url,             1);
    rb_define_method(ov_http_request_class, "query",            ov_http_request_get_query,           0);
    rb_define_method(ov_http_request_class, "query=",           ov_http_request_set_query,           1);
    rb_define_method(ov_http_request_class, "headers",          ov_http_request_get_headers,         0);
    rb_define_method(ov_http_request_class, "headers=",         ov_http_request_set_headers,         1);
    rb_define_method(ov_http_request_class, "username",         ov_http_request_get_username,        0);
    rb_define_method(ov_http_request_class, "username=",        ov_http_request_set_username,        1);
    rb_define_method(ov_http_request_class, "password",         ov_http_request_get_password,        0);
    rb_define_method(ov_http_request_class, "password=",        ov_http_request_set_password,        1);
    rb_define_method(ov_http_request_class, "token",            ov_http_request_get_token,           0);
    rb_define_method(ov_http_request_class, "token=",           ov_http_request_set_token,           1);
    rb_define_method(ov_http_request_class, "kerberos",         ov_http_request_get_kerberos,        0);
    rb_define_method(ov_http_request_class, "kerberos=",        ov_http_request_set_kerberos,        1);
    rb_define_method(ov_http_request_class, "body",             ov_http_request_get_body,            0);
    rb_define_method(ov_http_request_class, "body=",            ov_http_request_set_body,            1);
    rb_define_method(ov_http_request_class, "timeout",          ov_http_request_get_timeout,         0);
    rb_define_method(ov_http_request_class, "timeout=",         ov_http_request_set_timeout,         1);
    rb_define_method(ov_http_request_class, "connect_timeout",  ov_http_request_get_connect_timeout, 0);
    rb_define_method(ov_http_request_class, "connect_timeout=", ov_http_request_set_connect_timeout, 1);
    rb_define_method(ov_http_request_class, "inspect",          ov_http_request_inspect,             0);
    rb_define_method(ov_http_request_class, "to_s",             ov_http_request_inspect,             0);

    /* Define the symbols for the attributes: */
    URL_SYMBOL             = ID2SYM(rb_intern("url"));
    METHOD_SYMBOL          = ID2SYM(rb_intern("method"));
    QUERY_SYMBOL           = ID2SYM(rb_intern("query"));
    HEADERS_SYMBOL         = ID2SYM(rb_intern("headers"));
    USERNAME_SYMBOL        = ID2SYM(rb_intern("username"));
    PASSWORD_SYMBOL        = ID2SYM(rb_intern("password"));
    TOKEN_SYMBOL           = ID2SYM(rb_intern("token"));
    KERBEROS_SYMBOL        = ID2SYM(rb_intern("kerberos"));
    BODY_SYMBOL            = ID2SYM(rb_intern("body"));
    TIMEOUT_SYMBOL         = ID2SYM(rb_intern("timeout"));
    CONNECT_TIMEOUT_SYMBOL = ID2SYM(rb_intern("connect_timeout"));

    /* Define the symbols for the HTTP methods: */
    GET_SYMBOL    = ID2SYM(rb_intern("GET"));
    POST_SYMBOL   = ID2SYM(rb_intern("POST"));
    PUT_SYMBOL    = ID2SYM(rb_intern("PUT"));
    DELETE_SYMBOL = ID2SYM(rb_intern("DELETE"));
}
