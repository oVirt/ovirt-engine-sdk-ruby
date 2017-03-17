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

#ifndef __OV_HTTP_TRANSFER_H__
#define __OV_HTTP_TRANSFER_H__

#include <ruby.h>

#include <stdbool.h>
#include <curl/curl.h>

/* Data type and class: */
extern rb_data_type_t ov_http_transfer_type;
extern VALUE ov_http_transfer_class;

/* Content: */
typedef struct {
    VALUE client;   /* HttpClient */
    VALUE request;  /* HttpRequest */
    VALUE response; /* HttpResponse */
    VALUE in;       /* IO */
    VALUE out;      /* IO */
    struct curl_slist* headers;
    bool cancel;
} ov_http_transfer_object;

/* Macro to get the pointer: */
#define ov_http_transfer_ptr(object, ptr) \
    TypedData_Get_Struct((object), ov_http_transfer_object, &ov_http_transfer_type, (ptr))

/* Initialization function: */
extern void ov_http_transfer_define(void);

#endif
