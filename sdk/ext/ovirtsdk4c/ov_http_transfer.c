/*
Copyright (c) 2017 Red Hat, Inc.

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

#include "ov_module.h"
#include "ov_http_transfer.h"

/* Class: */
VALUE ov_http_transfer_class;

static void ov_http_transfer_mark(void* vptr) {
    ov_http_transfer_object* ptr;

    ptr = vptr;
    rb_gc_mark(ptr->client);
    rb_gc_mark(ptr->request);
    rb_gc_mark(ptr->response);
    rb_gc_mark(ptr->in);
    rb_gc_mark(ptr->out);
}

static void ov_http_transfer_free(void* vptr) {
    ov_http_transfer_object* ptr;

    ptr = vptr;
    xfree(ptr);
}

rb_data_type_t ov_http_transfer_type = {
    .wrap_struct_name = "OVHTTPTRANSFER",
    .function = {
        .dmark = ov_http_transfer_mark,
        .dfree = ov_http_transfer_free,
        .dsize = NULL,
        .reserved = { NULL, NULL }
    },
#ifdef RUBY_TYPED_FREE_IMMEDIATELY
    .parent = NULL,
    .data = NULL,
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
#endif
};

static VALUE ov_http_transfer_alloc(VALUE klass) {
    ov_http_transfer_object* ptr;

    ptr = ALLOC(ov_http_transfer_object);
    ptr->client   = Qnil;
    ptr->request  = Qnil;
    ptr->response = Qnil;
    ptr->in       = Qnil;
    ptr->out      = Qnil;
    ptr->headers  = NULL;
    ptr->cancel   = false;
    return TypedData_Wrap_Struct(klass, &ov_http_transfer_type, ptr);
}

static VALUE ov_http_transfer_inspect(VALUE self) {
    ov_http_transfer_object* ptr;

    ov_http_transfer_ptr(self, ptr);
    return rb_sprintf("#<%"PRIsVALUE":%p>", ov_http_transfer_class, ptr);
}

void ov_http_transfer_define(void) {
    /* Define the class: */
    ov_http_transfer_class = rb_define_class_under(ov_module, "HttpTransfer", rb_cData);

    /* Define the constructor: */
    rb_define_alloc_func(ov_http_transfer_class, ov_http_transfer_alloc);

    /* Define the methods: */
    rb_define_method(ov_http_transfer_class, "inspect", ov_http_transfer_inspect, 0);
    rb_define_method(ov_http_transfer_class, "to_s",    ov_http_transfer_inspect, 0);
}
