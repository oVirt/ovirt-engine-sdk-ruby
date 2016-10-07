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

static void ov_http_request_mark(ov_http_request_object *object) {
    if (!NIL_P(object->method)) {
        rb_gc_mark(object->method);
    }
    if (!NIL_P(object->url)) {
        rb_gc_mark(object->url);
    }
    if (!NIL_P(object->query)) {
        rb_gc_mark(object->query);
    }
    if (!NIL_P(object->headers)) {
        rb_gc_mark(object->headers);
    }
    if (!NIL_P(object->username)) {
        rb_gc_mark(object->username);
    }
    if (!NIL_P(object->password)) {
        rb_gc_mark(object->password);
    }
    if (!NIL_P(object->token)) {
        rb_gc_mark(object->token);
    }
    if (!NIL_P(object->kerberos)) {
        rb_gc_mark(object->kerberos);
    }
    if (!NIL_P(object->body)) {
        rb_gc_mark(object->body);
    }
}

static void ov_http_request_free(ov_http_request_object *object) {
    xfree(object);
}

static VALUE ov_http_request_alloc(VALUE klass) {
    ov_http_request_object* object = NULL;

    object = ALLOC(ov_http_request_object);
    object->method   = Qnil;
    object->url      = Qnil;
    object->query    = Qnil;
    object->headers  = Qnil;
    object->username = Qnil;
    object->password = Qnil;
    object->token    = Qnil;
    object->kerberos = Qnil;
    object->body     = Qnil;
    return Data_Wrap_Struct(klass, ov_http_request_mark, ov_http_request_free, object);
}

static VALUE ov_http_request_get_method(VALUE self) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    return object->method;
}

static VALUE ov_http_request_set_method(VALUE self, VALUE value) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    if (NIL_P(value)) {
        object->method = GET_SYMBOL;
    }
    else {
        Check_Type(value, T_SYMBOL);
        object->method = value;
    }
    return Qnil;
}

static VALUE ov_http_request_get_url(VALUE self) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    return object->url;
}

static VALUE ov_http_request_set_url(VALUE self, VALUE value) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    object->url = value;
    return Qnil;
}

static VALUE ov_http_request_get_query(VALUE self) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    return object->query;
}

static VALUE ov_http_request_set_query(VALUE self, VALUE value) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    if (!NIL_P(value)) {
        Check_Type(value, T_HASH);
    }
    object->query = value;
    return Qnil;
}

static VALUE ov_http_request_get_headers(VALUE self) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    return object->headers;
}

static VALUE ov_http_request_set_headers(VALUE self, VALUE value) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    if (NIL_P(value)) {
        object->headers = rb_hash_new();
    }
    else {
        Check_Type(value, T_HASH);
        object->headers = value;
    }
    return Qnil;
}

static VALUE ov_http_request_get_username(VALUE self) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    return object->username;
}

static VALUE ov_http_request_set_username(VALUE self, VALUE value) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    object->username = value;
    return Qnil;
}

static VALUE ov_http_request_get_password(VALUE self) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    return object->password;
}

static VALUE ov_http_request_set_password(VALUE self, VALUE value) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    object->password = value;
    return Qnil;
}

static VALUE ov_http_request_get_token(VALUE self) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    return object->token;
}

static VALUE ov_http_request_set_token(VALUE self, VALUE value) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    object->token = value;
    return Qnil;
}

static VALUE ov_http_request_get_kerberos(VALUE self) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    return object->kerberos;
}

static VALUE ov_http_request_set_kerberos(VALUE self, VALUE value) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    object->kerberos = RTEST(value);
    return Qnil;
}

static VALUE ov_http_request_get_body(VALUE self) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    return object->body;
}

static VALUE ov_http_request_set_body(VALUE self, VALUE value) {
    ov_http_request_object* object = NULL;

    Data_Get_Struct(self, ov_http_request_object, object);
    if (!NIL_P(value)) {
        Check_Type(value, T_STRING);
    }
    object->body = value;
    return Qnil;
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

    return self;
}

void ov_http_request_define(void) {
    /* Define the class: */
    ov_http_request_class = rb_define_class_under(ov_module, "HttpRequest", rb_cObject);

    /* Define the constructor: */
    rb_define_alloc_func(ov_http_request_class, ov_http_request_alloc);
    rb_define_method(ov_http_request_class, "initialize", ov_http_request_initialize, -1);

    /* Define the methods: */
    rb_define_method(ov_http_request_class, "method",    ov_http_request_get_method,   0);
    rb_define_method(ov_http_request_class, "method=",   ov_http_request_set_method,   1);
    rb_define_method(ov_http_request_class, "url",       ov_http_request_get_url,      0);
    rb_define_method(ov_http_request_class, "url=",      ov_http_request_set_url,      1);
    rb_define_method(ov_http_request_class, "query",     ov_http_request_get_query,    0);
    rb_define_method(ov_http_request_class, "query=",    ov_http_request_set_query,    1);
    rb_define_method(ov_http_request_class, "headers",   ov_http_request_get_headers,  0);
    rb_define_method(ov_http_request_class, "headers=",  ov_http_request_set_headers,  1);
    rb_define_method(ov_http_request_class, "username",  ov_http_request_get_username, 0);
    rb_define_method(ov_http_request_class, "username=", ov_http_request_set_username, 1);
    rb_define_method(ov_http_request_class, "password",  ov_http_request_get_password, 0);
    rb_define_method(ov_http_request_class, "password=", ov_http_request_set_password, 1);
    rb_define_method(ov_http_request_class, "token",     ov_http_request_get_token,    0);
    rb_define_method(ov_http_request_class, "token=",    ov_http_request_set_token,    1);
    rb_define_method(ov_http_request_class, "kerberos",  ov_http_request_get_kerberos, 0);
    rb_define_method(ov_http_request_class, "kerberos=", ov_http_request_set_kerberos, 1);
    rb_define_method(ov_http_request_class, "body",      ov_http_request_get_body,     0);
    rb_define_method(ov_http_request_class, "body=",     ov_http_request_set_body,     1);

    /* Define the symbols for the attributes: */
    URL_SYMBOL      = ID2SYM(rb_intern("url"));
    METHOD_SYMBOL   = ID2SYM(rb_intern("method"));
    QUERY_SYMBOL    = ID2SYM(rb_intern("query"));
    HEADERS_SYMBOL  = ID2SYM(rb_intern("headers"));
    USERNAME_SYMBOL = ID2SYM(rb_intern("username"));
    PASSWORD_SYMBOL = ID2SYM(rb_intern("password"));
    TOKEN_SYMBOL    = ID2SYM(rb_intern("token"));
    KERBEROS_SYMBOL = ID2SYM(rb_intern("kerberos"));
    BODY_SYMBOL     = ID2SYM(rb_intern("body"));

    /* Define the symbols for the HTTP methods: */
    GET_SYMBOL    = ID2SYM(rb_intern("GET"));
    POST_SYMBOL   = ID2SYM(rb_intern("POST"));
    PUT_SYMBOL    = ID2SYM(rb_intern("PUT"));
    DELETE_SYMBOL = ID2SYM(rb_intern("DELETE"));
}
