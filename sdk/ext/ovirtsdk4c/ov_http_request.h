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

#ifndef __OV_HTTP_REQUEST_H__
#define __OV_HTTP_REQUEST_H__

/* Class: */
VALUE ov_http_request_class;

/* Symbols for HTTP methods: */
VALUE GET_SYMBOL;
VALUE POST_SYMBOL;
VALUE PUT_SYMBOL;
VALUE DELETE_SYMBOL;

/* Content: */
typedef struct {
    VALUE method;   /* Symbol */
    VALUE url;      /* String */
    VALUE query;    /* Hash<String, String> */
    VALUE headers;  /* Hash<String, String> */
    VALUE username; /* String */
    VALUE password; /* String */
    VALUE token;    /* String */
    VALUE kerberos; /* Boolean */
    VALUE body;     /* String */
} ov_http_request_object;

/* Initialization function: */
extern void ov_http_request_define(void);

#endif
