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

#ifndef __OV_HTTP_CLIENT_H__
#define __OV_HTTP_CLIENT_H__

#include <ruby.h>

#include <curl/curl.h>
#include <stdbool.h>

/* Data type and class: */
extern rb_data_type_t ov_http_client_type;
extern VALUE ov_http_client_class;

/* Content: */
typedef struct {
    /* The libcurl multi handle, used to implement multiple simultaneous requests: */
    CURLM* handle;

    /* The libcurl share handle, used to share cookie data between multiple requests: */
    CURLSH* share;

    /* The logger: */
    VALUE log;

    /* The max number of requests that can be processed simultaneously by libcurl. Will be calculated multiplying the
       max number of connections by the pipeline length: */
    int limit;

    /* This queue contains the requests that have not yet been sent to libcurl for processing: */
    VALUE queue;

    /* This hash stores the transfers that are pending. The key of the hash is the request that initiated the transfer,
       and the value is the transfer itself. */
    VALUE pending;

    /* This hash stores the completed transfers. The key of the hash is the request, and the value is either the
       response to that request, or else the exception that was generated while trying to process it. */
    VALUE completed;

    /* Copies of the options passed to the constructor: */
    bool compress;
    bool debug;
    bool insecure;
    char* ca_file;
    char* proxy_url;
    char* proxy_username;
    char* proxy_password;
    int timeout;
    int connect_timeout;
    char* cookies;
} ov_http_client_object;

/* Macro to get the pointer: */
#define ov_http_client_ptr(object, ptr) \
    TypedData_Get_Struct((object), ov_http_client_object, &ov_http_client_type, (ptr))

/* Initialization function: */
extern void ov_http_client_define(void);

#endif
