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
#include <ruby/thread.h>

#include <ctype.h>
#include <curl/curl.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "ov_module.h"
#include "ov_error.h"
#include "ov_http_client.h"
#include "ov_http_request.h"
#include "ov_http_response.h"

/* Class: */
VALUE ov_http_client_class;

/* Symbols: */
static VALUE CA_FILE_SYMBOL;
static VALUE COMPRESS_SYMBOL;
static VALUE DEBUG_SYMBOL;
static VALUE INSECURE_SYMBOL;
static VALUE LOG_SYMBOL;
static VALUE PASSWORD_SYMBOL;
static VALUE TIMEOUT_SYMBOL;
static VALUE USERNAME_SYMBOL;
static VALUE PROXY_URL_SYMBOL;
static VALUE PROXY_USERNAME_SYMBOL;
static VALUE PROXY_PASSWORD_SYMBOL;

/* Method identifiers: */
static ID DEBUG_ID;
static ID ENCODE_WWW_FORM_ID;
static ID INFO_ID;
static ID INFO_Q_ID;
static ID READ_ID;
static ID STRING_ID;
static ID STRING_IO_ID;
static ID URI_ID;
static ID WRITE_ID;

/* References to classes: */
static VALUE URI_CLASS;
static VALUE STRING_IO_CLASS;

/* Constants: */
const char CR = '\x0D';
const char LF = '\x0A';

/* Before version 7.38.0 of libcurl the NEGOTIATE authentication method was named GSSNEGOTIATE: */
#ifndef CURLAUTH_NEGOTIATE
#define CURLAUTH_NEGOTIATE CURLAUTH_GSSNEGOTIATE
#endif

typedef struct {
    ov_http_client_object* object;
    ov_http_response_object* response;
    VALUE in; /* IO */
    VALUE out; /* IO */
    bool cancel;
    CURLcode result;
} ov_http_client_perform_context;

typedef struct {
    ov_http_client_object* object;
    char* ptr;
    size_t size;
    size_t nmemb;
    VALUE io; /* IO */
    size_t result;
} ov_http_client_io_context;

typedef struct {
    ov_http_response_object* response;
    char* buffer;
    size_t size;
    size_t nitems;
    size_t result;
} ov_http_client_header_context;

typedef struct {
    ov_http_client_object* object;
    curl_infotype type;
    char* data;
    size_t size;
} ov_http_client_debug_context;

static void ov_http_client_check_closed(ov_http_client_object* object) {
    if (object->curl == NULL) {
        rb_raise(ov_error_class, "The client is already closed");
    }
}

static void ov_http_client_mark(void* vptr) {
    ov_http_client_object* ptr;

    ptr = vptr;
    rb_gc_mark(ptr->log);

}

static void ov_http_client_free(void* vptr) {
    ov_http_client_object* ptr;

    /* Get the pointer: */
    ptr = vptr;

    /* Release the resources used by libcurl. The callbacks need to be cleared before cleaning the libcurl handle
       because libcurl calls them during the cleanup, and we can't call Ruby code from this method. */
    if (ptr->curl != NULL) {
        curl_easy_setopt(ptr->curl, CURLOPT_DEBUGFUNCTION, NULL);
        curl_easy_setopt(ptr->curl, CURLOPT_WRITEFUNCTION, NULL);
        curl_easy_setopt(ptr->curl, CURLOPT_HEADERFUNCTION, NULL);
        curl_easy_cleanup(ptr->curl);
        ptr->curl = NULL;
    }

    /* Free this object: */
    xfree(ptr);
}

rb_data_type_t ov_http_client_type = {
    .wrap_struct_name = "OVHTTPCLIENT",
    .function = {
        .dmark = ov_http_client_mark,
        .dfree = ov_http_client_free,
        .dsize = NULL,
        .reserved = { NULL, NULL }
    },
#ifdef RUBY_TYPED_FREE_IMMEDIATELY
    .parent = NULL,
    .data = NULL,
    .flags = RUBY_TYPED_FREE_IMMEDIATELY,
#endif
};

static VALUE ov_http_client_alloc(VALUE klass) {
    ov_http_client_object* ptr;

    ptr = ALLOC(ov_http_client_object);
    ptr->curl = NULL;
    ptr->log  = Qnil;
    return TypedData_Wrap_Struct(klass, &ov_http_client_type, ptr);
}

static VALUE ov_http_client_close(VALUE self) {
    ov_http_client_object* object;

    /* Get the pointer to the native object and check that it isn't closed: */
    ov_http_client_ptr(self, object);
    ov_http_client_check_closed(object);

    /* Release the resources used by libcurl. In this case we don't need to clear the callbacks in advance, because
       we can safely call Ruby code from this method. */
    curl_easy_cleanup(object->curl);
    object->curl = NULL;

    return Qnil;
}

static void* ov_http_client_read_task(void* data) {
    VALUE bytes;
    VALUE count;
    ov_http_client_io_context* io_context = (ov_http_client_io_context*) data;

    /* Read the data using the "read" method and write the raw bytes to the buffer provided by libcurl: */
    count = INT2NUM(io_context->size * io_context->nmemb);
    bytes = rb_funcall(io_context->io, READ_ID, 1, count);
    if (NIL_P(bytes)) {
       io_context->result = 0;
    }
    else {
       io_context->result = RSTRING_LEN(bytes);
       memcpy(io_context->ptr, StringValuePtr(bytes), io_context->result);
    }

    return NULL;
}

static size_t ov_http_client_read_function(char *ptr, size_t size, size_t nmemb, void *userdata) {
    ov_http_client_perform_context* perform_context = (ov_http_client_perform_context*) userdata;
    ov_http_client_io_context io_context;

    /* Check if the operation has been cancelled, and return immediately, this will cause the perform method to
       return an error to the caller: */
    if (perform_context->cancel) {
        return CURL_READFUNC_ABORT;
    }

    /* Execute the read with the global interpreter lock acquired, as it needs to call Ruby methods: */
    io_context.object = perform_context->object;
    io_context.ptr = ptr;
    io_context.size = size;
    io_context.nmemb = nmemb;
    io_context.io = perform_context->in;
    rb_thread_call_with_gvl(ov_http_client_read_task, &io_context);
    return io_context.result;
}

static void* ov_http_client_write_task(void* data) {
    VALUE bytes;
    VALUE count;
    ov_http_client_io_context* io_context = (ov_http_client_io_context*) data;

    /* Convert the buffer to a Ruby string and write it to the IO object, using the "write" method: */
    bytes = rb_str_new(io_context->ptr, io_context->size * io_context->nmemb);
    count = rb_funcall(io_context->io, WRITE_ID, 1, bytes);
    io_context->result = NUM2INT(count);

    return NULL;
}

static size_t ov_http_client_write_function(char *ptr, size_t size, size_t nmemb, void *userdata) {
    ov_http_client_perform_context* perform_context = (ov_http_client_perform_context*) userdata;
    ov_http_client_io_context io_context;

    /* Check if the operation has been cancelled, and return immediately, this will cause the perform method to
       return an error to the caller: */
    if (perform_context->cancel) {
        return 0;
    }

    /* Execute the write with the global interpreter lock acquired, as it needs to call Ruby methods: */
    io_context.object = perform_context->object;
    io_context.ptr = ptr;
    io_context.size = size;
    io_context.nmemb = nmemb;
    io_context.io = perform_context->out;
    rb_thread_call_with_gvl(ov_http_client_write_task, &io_context);
    return io_context.result;
}

static void* ov_http_client_header_task(void* data) {
    VALUE name;
    VALUE value;
    char* buffer;
    char* pointer;
    size_t length;
    ov_http_client_header_context* header_context = (ov_http_client_header_context*) data;

    /* We should always tell the library that we processed all the data: */
    header_context->result = header_context->size * header_context->nitems;

    /* Remove trailing white space: */
    length = header_context->result;
    buffer = header_context->buffer;
    while (length > 0 && isspace(buffer[length - 1])) {
        length--;
    }

    /* Parse the header and add it to the response object: */
    pointer = memchr(buffer, ':', length);
    if (pointer != NULL) {
        name = rb_str_new(buffer, pointer - buffer);
        pointer++;
        while (pointer - buffer < length && isspace(*pointer)) {
            pointer++;
        }
        value = rb_str_new(pointer, length - (pointer - buffer));
        rb_hash_aset(header_context->response->headers, name, value);
    }

    return NULL;
}

static size_t ov_http_client_header_function(char *buffer, size_t size, size_t nitems, void *userdata) {
    ov_http_client_header_context header_context;
    ov_http_client_perform_context* perform_context = (ov_http_client_perform_context*) userdata;

    /* Check if the operation has been cancelled, and return immediately, this will cause the perform method to
       return an error to the caller: */
    if (perform_context->cancel) {
        return 0;
    }

    /* Parse the header with the global intepreter lock acquired, as it needs to call Ruby methods: */
    header_context.response = perform_context->response;
    header_context.buffer = buffer;
    header_context.size = size;
    header_context.nitems = nitems;
    rb_thread_call_with_gvl(ov_http_client_header_task, &header_context);
    return header_context.result;
}

static void* ov_http_client_debug_task(void* data) {
    VALUE line;
    VALUE log;
    int c;
    char* text;
    ov_http_client_debug_context* debug_context = (ov_http_client_debug_context*) data;
    size_t i;
    size_t j;
    size_t size;
    int s;

    /* Do nothing if there is no log: */
    log = debug_context->object->log;
    if (NIL_P(log)) {
        return NULL;
    }

    /* Split the text into lines, and send a debug message for each line: */
    text = debug_context->data;
    size = debug_context->size;
    i = 0;
    s = 0;
    for (j = 0; j <= size; j++) {
        c = j < size? text[j]: -1;
        switch (s) {
        case 0:
            if (c == CR || c == LF || c == -1) {
                line = rb_str_new(text + i, j - i);
                rb_funcall(log, DEBUG_ID, 1, line);
                i = j + 1;
                s = 1;
            }
            break;
        case 1:
            if (c == CR || c == LF || c == -1) {
                i++;
            }
            else {
                s = 0;
            }
            break;
        }
    }

    return NULL;
}

static int ov_http_client_debug_function(CURL* handle, curl_infotype type, char* data, size_t size, void* userptr) {
    ov_http_client_debug_context debug_context;
    ov_http_client_perform_context* perform_context = (ov_http_client_perform_context*) userptr;

    /* Execute the debug code with the global interpreter lock acquired, as it needs to call Ruby methods: */
    debug_context.object = perform_context->object;
    debug_context.type = type;
    debug_context.data = data;
    debug_context.size = size;
    rb_thread_call_with_gvl(ov_http_client_debug_task, &debug_context);
    return 0;
}

static VALUE ov_http_client_initialize(int argc, VALUE* argv, VALUE self) {
    VALUE opt;
    VALUE opts;
    bool compress;
    bool debug;
    bool insecure;
    char* ca_file;
    char* proxy_password;
    char* proxy_url;
    char* proxy_username;
    int timeout;
    ov_http_client_object* object;

    /* Get the pointer to the native object: */
    ov_http_client_ptr(self, object);

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

    /* Get the value of the 'insecure' parameter: */
    opt = rb_hash_aref(opts, INSECURE_SYMBOL);
    if (NIL_P(opt)) {
        insecure = false;
    }
    else {
        insecure = RTEST(opt);
    }

    /* Get the value of the 'ca_file' parameter: */
    opt = rb_hash_aref(opts, CA_FILE_SYMBOL);
    if (NIL_P(opt)) {
        ca_file = NULL;
    }
    else {
        Check_Type(opt, T_STRING);
        ca_file = StringValueCStr(opt);
    }

    /* Get the value of the 'debug' parameter: */
    opt = rb_hash_aref(opts, DEBUG_SYMBOL);
    if (NIL_P(opt)) {
        debug = false;
    }
    else {
        debug = RTEST(opt);
    }

    /* Get the value of the 'log' parameter: */
    opt = rb_hash_aref(opts, LOG_SYMBOL);
    if (NIL_P(opt)) {
        object->log = Qnil;
    }
    else {
        object->log = opt;
    }

    /* Get the value of the 'timeout' parameter: */
    opt = rb_hash_aref(opts, TIMEOUT_SYMBOL);
    if (NIL_P(opt)) {
        timeout = 0;
    }
    else {
        Check_Type(opt, T_FIXNUM);
        timeout = NUM2INT(opt);
    }

    /* Get the value of the 'compress' parameter: */
    opt = rb_hash_aref(opts, COMPRESS_SYMBOL);
    if (NIL_P(opt)) {
        compress = false;
    }
    else {
        compress = RTEST(opt);
    }

    /* Get the value of the 'proxy_url' parameter: */
    opt = rb_hash_aref(opts, PROXY_URL_SYMBOL);
    if (NIL_P(opt)) {
        proxy_url = NULL;
    }
    else {
        Check_Type(opt, T_STRING);
        proxy_url = StringValueCStr(opt);
    }

    /* Get the value of the 'proxy_username' parameter: */
    opt = rb_hash_aref(opts, PROXY_USERNAME_SYMBOL);
    if (NIL_P(opt)) {
        proxy_username = NULL;
    }
    else {
        Check_Type(opt, T_STRING);
        proxy_username = StringValueCStr(opt);
    }

    /* Get the value of the 'proxy_password' parameter: */
    opt = rb_hash_aref(opts, PROXY_PASSWORD_SYMBOL);
    if (NIL_P(opt)) {
        proxy_password = NULL;
    }
    else {
        Check_Type(opt, T_STRING);
        proxy_password = StringValueCStr(opt);
    }

    /* Create the libcurl object: */
    object->curl = curl_easy_init();
    if (object->curl == NULL) {
        rb_raise(ov_error_class, "Can't create libcurl object");
    }

    /* Configure TLS parameters: */
    if (insecure) {
        curl_easy_setopt(object->curl, CURLOPT_SSL_VERIFYPEER, 0L);
        curl_easy_setopt(object->curl, CURLOPT_SSL_VERIFYHOST, 0L);
    }
    if (ca_file != NULL) {
        curl_easy_setopt(object->curl, CURLOPT_CAINFO, ca_file);
    }

    /* Configure the timeout: */
    curl_easy_setopt(object->curl, CURLOPT_TIMEOUT, timeout);

    /* Configure compression of responses (setting the value to zero length string means accepting all the
       compression types that libcurl supports): */
    if (compress) {
        curl_easy_setopt(object->curl, CURLOPT_ENCODING, "");
    }

    /* Configure debug mode: */
    if (debug) {
        curl_easy_setopt(object->curl, CURLOPT_VERBOSE, 1L);
        curl_easy_setopt(object->curl, CURLOPT_DEBUGFUNCTION, ov_http_client_debug_function);
    }

    /* Configure the proxy: */
    if (proxy_url != NULL) {
        curl_easy_setopt(object->curl, CURLOPT_PROXY, proxy_url);
        if (proxy_username != NULL && proxy_password != NULL) {
            curl_easy_setopt(object->curl, CURLOPT_PROXYUSERNAME, proxy_username);
            curl_easy_setopt(object->curl, CURLOPT_PROXYPASSWORD, proxy_password);
        }
    }

    /* Configure callbacks: */
    curl_easy_setopt(object->curl, CURLOPT_READFUNCTION, ov_http_client_read_function);
    curl_easy_setopt(object->curl, CURLOPT_WRITEFUNCTION, ov_http_client_write_function);
    curl_easy_setopt(object->curl, CURLOPT_HEADERFUNCTION, ov_http_client_header_function);

    return self;
}

static VALUE ov_http_client_build_url(VALUE self, VALUE url, VALUE query) {
    ov_http_client_object* object;

    /* Get the pointer to the native object and check that it isn't closed: */
    ov_http_client_ptr(self, object);
    ov_http_client_check_closed(object);

    /* Copy the URL: */
    if (NIL_P(url)) {
        rb_raise(ov_error_class, "The 'url' parameter can't be nil");
    }
    Check_Type(url, T_STRING);

    /* Append the query: */
    if (!NIL_P(query)) {
        Check_Type(query, T_HASH);
        if (RHASH_SIZE(query) > 0) {
            url = rb_sprintf("%"PRIsVALUE"?%"PRIsVALUE"", url, rb_funcall(URI_CLASS, ENCODE_WWW_FORM_ID, 1, query));
        }
    }

    return url;
}

static int ov_http_client_add_header(VALUE name, VALUE value, struct curl_slist** headers) {
    VALUE header = Qnil;

    header = rb_sprintf("%"PRIsVALUE": %"PRIsVALUE"", name, value);
    *headers = curl_slist_append(*headers, StringValueCStr(header));

    return ST_CONTINUE;
}

static void* ov_http_client_perform_task(void* data) {
    ov_http_client_perform_context* perform_context = (ov_http_client_perform_context*) data;

    /* Call the libcurl 'perform' method, and store the result in the context: */
    perform_context->result = curl_easy_perform(perform_context->object->curl);

    return NULL;
}

static void ov_http_client_perform_cancel(void* data) {
    ov_http_client_perform_context* perform_context = (ov_http_client_perform_context*) data;

    /* Set the cancel flag so that the operation will be actually aborted the next time that libcurl calls the write
       function: */
    perform_context->cancel = true;
}

static void ov_http_client_log_info(VALUE log, const char* format, ...) {
    VALUE enabled;
    VALUE message;
    va_list args;

    if (!NIL_P(log)) {
        enabled = rb_funcall(log, INFO_Q_ID, 0);
        if (RTEST(enabled)) {
            va_start(args, format);
            message = rb_vsprintf(format, args);
            rb_funcall(log, INFO_ID, 1, message);
            va_end(args);
        }
    }
}

static VALUE ov_http_client_send(VALUE self, VALUE request, VALUE response) {
    VALUE header;
    VALUE url;
    long response_code;
    ov_http_client_object* object;
    ov_http_client_perform_context perform_context;
    ov_http_request_object* request_object;
    ov_http_response_object* response_object;
    struct curl_slist* headers;

    /* Get the pointer to the native object and check that it isn't closed: */
    ov_http_client_ptr(self, object);
    ov_http_client_check_closed(object);

    /* Check the type of request and get the pointer to the native object: */
    if (NIL_P(request)) {
        rb_raise(ov_error_class, "The 'request' parameter can't be nil");
    }
    if (!rb_obj_is_instance_of(request, ov_http_request_class)) {
        rb_raise(ov_error_class, "The 'request' parameter isn't an instance of class 'HttpRequest'");
    }
    ov_http_request_ptr(request, request_object);

    /* Check the type of response and get the pointer to the native object: */
    if (NIL_P(response)) {
        rb_raise(ov_error_class, "The 'response' parameter can't be nil");
    }
    if (!rb_obj_is_instance_of(response, ov_http_response_class)) {
        rb_raise(ov_error_class, "The 'response' parameter isn't an instance of class 'HttpResponse'");
    }
    ov_http_response_ptr(response, response_object);

    /* Build and set the URL: */
    url = ov_http_client_build_url(self, request_object->url, request_object->query);
    curl_easy_setopt(object->curl, CURLOPT_URL, StringValueCStr(url));

    /* Initialize the list of headers: */
    headers = NULL;

    /* Set the method: */
    if (rb_eql(request_object->method, POST_SYMBOL)) {
       headers = curl_slist_append(headers, "Transfer-Encoding: chunked");
       headers = curl_slist_append(headers, "Expect:");
       curl_easy_setopt(object->curl, CURLOPT_POST, 1L);
    }
    else if (rb_eql(request_object->method, PUT_SYMBOL)) {
       curl_easy_setopt(object->curl, CURLOPT_UPLOAD, 1L);
       curl_easy_setopt(object->curl, CURLOPT_PUT, 1L);
    }
    else if (rb_eql(request_object->method, DELETE_SYMBOL)) {
       curl_easy_setopt(object->curl, CURLOPT_HTTPGET, 1L);
       curl_easy_setopt(object->curl, CURLOPT_CUSTOMREQUEST, "DELETE");
    }
    else if (rb_eql(request_object->method, GET_SYMBOL)) {
       curl_easy_setopt(object->curl, CURLOPT_HTTPGET, 1L);
    }

    /* Set authentication details: */
    if (!NIL_P(request_object->token)) {
        header = rb_sprintf("Authorization: Bearer %"PRIsVALUE"", request_object->token);
        headers = curl_slist_append(headers, StringValueCStr(header));
    }
    else if (!NIL_P(request_object->username) && !NIL_P(request_object->password)) {
        curl_easy_setopt(object->curl, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_easy_setopt(object->curl, CURLOPT_USERNAME, StringValueCStr(request_object->username));
        curl_easy_setopt(object->curl, CURLOPT_PASSWORD, StringValueCStr(request_object->password));
    }
    else if (RTEST(request_object->kerberos)) {
        curl_easy_setopt(object->curl, CURLOPT_HTTPAUTH, CURLAUTH_NEGOTIATE);
    }

    /* Set the headers: */
    if (!NIL_P(request_object->headers)) {
        rb_hash_foreach(request_object->headers, ov_http_client_add_header, (VALUE) &headers);
    }
    curl_easy_setopt(object->curl, CURLOPT_HTTPHEADER, headers);

    /* Send a summary of the request to the log: */
    ov_http_client_log_info(
        object->log,
        "Sending '%"PRIsVALUE"' request to URL '%"PRIsVALUE"'.",
        request_object->method,
        url
    );

    /* Performing the request is a potentially lengthy and blocking operation, so we need to make sure that it runs
       without the global interpreter lock acquired as much as possible: */
    perform_context.object = object;
    perform_context.response = response_object;
    perform_context.cancel = false;
    if (NIL_P(request_object->body)) {
        perform_context.in = rb_class_new_instance(0, NULL, STRING_IO_CLASS);
    }
    else {
        perform_context.in = rb_class_new_instance(1, &request_object->body, STRING_IO_CLASS);
    }
    perform_context.out = rb_class_new_instance(0, NULL, STRING_IO_CLASS);
    curl_easy_setopt(object->curl, CURLOPT_READDATA, &perform_context);
    curl_easy_setopt(object->curl, CURLOPT_WRITEDATA, &perform_context);
    curl_easy_setopt(object->curl, CURLOPT_HEADERDATA, &perform_context);
    curl_easy_setopt(object->curl, CURLOPT_DEBUGDATA, &perform_context);
    rb_thread_call_without_gvl(
        ov_http_client_perform_task,
        &perform_context,
        ov_http_client_perform_cancel,
        &perform_context
    );

    /* Free the headers and clear the libcurl object, regardless of the result of the request: */
    curl_slist_free_all(headers);
    curl_easy_setopt(object->curl, CURLOPT_URL, NULL);
    curl_easy_setopt(object->curl, CURLOPT_READDATA, NULL);
    curl_easy_setopt(object->curl, CURLOPT_WRITEDATA, NULL);
    curl_easy_setopt(object->curl, CURLOPT_HEADERDATA, NULL);
    curl_easy_setopt(object->curl, CURLOPT_DEBUGDATA, NULL);
    curl_easy_setopt(object->curl, CURLOPT_CUSTOMREQUEST, NULL);
    curl_easy_setopt(object->curl, CURLOPT_UPLOAD, 0L);
    curl_easy_setopt(object->curl, CURLOPT_HTTPAUTH, 0L);
    curl_easy_setopt(object->curl, CURLOPT_USERNAME, "");
    curl_easy_setopt(object->curl, CURLOPT_PASSWORD, "");

    /* Check the result of the request: */
    if (perform_context.result != CURLE_OK) {
        rb_raise(ov_error_class, "Can't send request: %s", curl_easy_strerror(perform_context.result));
    }

    /* Get the response code: */
    curl_easy_getinfo(object->curl, CURLINFO_RESPONSE_CODE, &response_code);
    response_object->code = LONG2NUM(response_code);

    /* Get the response body: */
    response_object->body = rb_funcall(perform_context.out, STRING_ID, 0);

    /* Send a summary of the response to the log: */
    ov_http_client_log_info(
        object->log,
        "Received response code '%"PRIsVALUE"'.",
        response_object->code
    );

    return Qnil;
}

void ov_http_client_define(void) {
    CURLcode code;

    /* Load requirements: */
    rb_require("stringio");
    rb_require("uri");

    /* Define the class: */
    ov_http_client_class = rb_define_class_under(ov_module, "HttpClient", rb_cObject);

    /* Define the constructor: */
    rb_define_alloc_func(ov_http_client_class, ov_http_client_alloc);
    rb_define_method(ov_http_client_class, "initialize", ov_http_client_initialize, -1);

    /* Define the methods: */
    rb_define_method(ov_http_client_class, "build_url", ov_http_client_build_url, 2);
    rb_define_method(ov_http_client_class, "close",     ov_http_client_close,     0);
    rb_define_method(ov_http_client_class, "send",      ov_http_client_send,      2);

    /* Define the symbols: */
    USERNAME_SYMBOL       = ID2SYM(rb_intern("username"));
    PASSWORD_SYMBOL       = ID2SYM(rb_intern("password"));
    INSECURE_SYMBOL       = ID2SYM(rb_intern("insecure"));
    CA_FILE_SYMBOL        = ID2SYM(rb_intern("ca_file"));
    DEBUG_SYMBOL          = ID2SYM(rb_intern("debug"));
    LOG_SYMBOL            = ID2SYM(rb_intern("log"));
    COMPRESS_SYMBOL       = ID2SYM(rb_intern("compress"));
    TIMEOUT_SYMBOL        = ID2SYM(rb_intern("timeout"));
    PROXY_URL_SYMBOL      = ID2SYM(rb_intern("proxy_url"));
    PROXY_USERNAME_SYMBOL = ID2SYM(rb_intern("proxy_username"));
    PROXY_PASSWORD_SYMBOL = ID2SYM(rb_intern("proxy_password"));

    /* Define the method identifiers: */
    DEBUG_ID           = rb_intern("debug");
    ENCODE_WWW_FORM_ID = rb_intern("encode_www_form");
    INFO_ID            = rb_intern("info");
    INFO_Q_ID          = rb_intern("info?");
    READ_ID            = rb_intern("read");
    STRING_ID          = rb_intern("string");
    STRING_IO_ID       = rb_intern("StringIO");
    URI_ID             = rb_intern("URI");
    WRITE_ID           = rb_intern("write");

    /* Locate classes: */
    STRING_IO_CLASS = rb_const_get(rb_cObject, STRING_IO_ID);
    URI_CLASS       = rb_const_get(rb_cObject, URI_ID);

    /* Initialize libcurl: */
    code = curl_global_init(CURL_GLOBAL_DEFAULT);
    if (code != CURLE_OK) {
        rb_raise(ov_error_class, "Can't initialize libcurl: %s", curl_easy_strerror(code));
    }
}
