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
#include <sys/time.h>
#include <sys/select.h>

#include "ov_module.h"
#include "ov_error.h"
#include "ov_string.h"
#include "ov_http_client.h"
#include "ov_http_request.h"
#include "ov_http_response.h"
#include "ov_http_transfer.h"

/* Class: */
VALUE ov_http_client_class;

/* Symbols: */
static VALUE CA_FILE_SYMBOL;
static VALUE COMPRESS_SYMBOL;
static VALUE CONNECTIONS_SYMBOL;
static VALUE DEBUG_SYMBOL;
static VALUE INSECURE_SYMBOL;
static VALUE LOG_SYMBOL;
static VALUE PASSWORD_SYMBOL;
static VALUE PIPELINE_SYMBOL;
static VALUE PROXY_PASSWORD_SYMBOL;
static VALUE PROXY_URL_SYMBOL;
static VALUE PROXY_USERNAME_SYMBOL;
static VALUE TIMEOUT_SYMBOL;
static VALUE CONNECT_TIMEOUT_SYMBOL;
static VALUE COOKIES_SYMBOL;

/* Method identifiers: */
static ID COMPARE_BY_IDENTITY_ID;
static ID DEBUG_ID;
static ID DOWNCASE_ID;
static ID ENCODE_WWW_FORM_ID;
static ID INFO_ID;
static ID INFO_Q_ID;
static ID READ_ID;
static ID STRING_ID;
static ID STRING_IO_ID;
static ID URI_ID;
static ID WARN_ID;
static ID WARN_Q_ID;
static ID WRITE_ID;

/* References to classes: */
static VALUE STRING_IO_CLASS;
static VALUE URI_CLASS;

/* Constants: */
const char CR = '\x0D';
const char LF = '\x0A';

/* Version of libcurl: */
static curl_version_info_data* libcurl_version;

/* Before version 7.38.0 of libcurl the NEGOTIATE authentication method was named GSSNEGOTIATE: */
#ifndef CURLAUTH_NEGOTIATE
#define CURLAUTH_NEGOTIATE CURLAUTH_GSSNEGOTIATE
#endif

/* Before version 7.43.0 of libcurl the CURLPIPE_HTTP1 constant didn't exist, the value 1 was used
   directly instead: */
#ifndef CURLPIPE_HTTP1
#define CURLPIPE_HTTP1 1
#endif

/* Define options that may not be available in some versions of libcurl: */
#if LIBCURL_VERSION_NUM < 0x071e00 /* 7.30.0 */
#define CURLMOPT_MAX_HOST_CONNECTIONS 7
#define CURLMOPT_MAX_PIPELINE_LENGTH 8
#define CURLMOPT_MAX_TOTAL_CONNECTIONS 13
#endif

#if LIBCURL_VERSION_NUM < 0x070f03 /* 7.16.3 */
#define CURLMOPT_MAXCONNECTS 6
#endif

#if LIBCURL_VERSION_NUM < 0x070f00 /* 7.16.0 */
#define CURLMOPT_PIPELINING 3
#endif

typedef struct {
    VALUE io; /* IO */
    char* ptr;
    size_t size;
    size_t nmemb;
    size_t result;
} ov_http_client_io_context;

typedef struct {
    VALUE response; /* HttpResponse */
    char* buffer;
    size_t size;
    size_t nitems;
    size_t result;
} ov_http_client_header_context;

typedef struct {
    VALUE client; /* HttpClient */
    curl_infotype type;
    char* data;
    size_t size;
} ov_http_client_debug_context;

typedef struct {
    CURLM* handle;
    CURLcode code;
    bool cancel;
} ov_http_client_wait_context;


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

static void ov_http_client_log_warn(VALUE log, const char* format, ...) {
    VALUE enabled;
    VALUE message;
    va_list args;

    if (!NIL_P(log)) {
        enabled = rb_funcall(log, WARN_Q_ID, 0);
        if (RTEST(enabled)) {
            va_start(args, format);
            message = rb_vsprintf(format, args);
            rb_funcall(log, WARN_ID, 1, message);
            va_end(args);
        }
    }
}

static void ov_http_client_check_closed(ov_http_client_object* object) {
    if (object->handle == NULL) {
        rb_raise(ov_error_class, "The client is already closed");
    }
}

static void ov_http_client_mark(void* vptr) {
    ov_http_client_object* ptr;

    ptr = vptr;
    rb_gc_mark(ptr->log);
    rb_gc_mark(ptr->queue);
    rb_gc_mark(ptr->pending);
    rb_gc_mark(ptr->completed);
}

static void ov_http_client_free(void* vptr) {
    ov_http_client_object* ptr;

    /* Get the pointer to the object: */
    ptr = vptr;

    /* Release the resources used by libcurl: */
    if (ptr->handle != NULL) {
        curl_multi_cleanup(ptr->handle);
        curl_share_cleanup(ptr->share);
        ptr->handle = NULL;
    }

    /* Free the strings: */
    ov_string_free(ptr->ca_file);
    ov_string_free(ptr->proxy_url);
    ov_string_free(ptr->proxy_username);
    ov_string_free(ptr->proxy_password);
    ov_string_free(ptr->cookies);

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
    ptr->handle = NULL;
    ptr->share = NULL;
    ptr->log = Qnil;
    ptr->limit = 0;
    ptr->queue = Qnil;
    ptr->pending = Qnil;
    ptr->completed = Qnil;
    ptr->compress = false;
    ptr->debug = false;
    ptr->insecure = false;
    ptr->ca_file = NULL;
    ptr->proxy_url = NULL;
    ptr->proxy_username = NULL;
    ptr->proxy_password = NULL;
    ptr->timeout = 0;
    ptr->connect_timeout = 0;
    ptr->cookies = NULL;
    return TypedData_Wrap_Struct(klass, &ov_http_client_type, ptr);
}

static VALUE ov_http_client_close(VALUE self) {
    ov_http_client_object* ptr;

    /* Get the pointer to the native object and check that it isn't closed: */
    ov_http_client_ptr(self, ptr);
    ov_http_client_check_closed(ptr);

    /* Release the resources used by libcurl: */
    curl_multi_cleanup(ptr->handle);
    ptr->handle = NULL;

    return Qnil;
}

static void* ov_http_client_read_task(void* data) {
    VALUE bytes;
    VALUE count;
    ov_http_client_io_context* context_ptr;

    /* The passed data is a pointer to the IO context: */
    context_ptr = (ov_http_client_io_context*) data;

    /* Read the data using the "read" method and write the raw bytes to the buffer provided by libcurl: */
    count = INT2NUM(context_ptr->size * context_ptr->nmemb);
    bytes = rb_funcall(context_ptr->io, READ_ID, 1, count);
    if (NIL_P(bytes)) {
       context_ptr->result = 0;
    }
    else {
       context_ptr->result = RSTRING_LEN(bytes);
       memcpy(context_ptr->ptr, StringValuePtr(bytes), context_ptr->result);
    }

    return NULL;
}

static size_t ov_http_client_read_function(char *ptr, size_t size, size_t nmemb, void *userdata) {
    VALUE transfer;
    ov_http_client_io_context context;
    ov_http_transfer_object* transfer_ptr;

    /* The passed user data is the transfer: */
    transfer = (VALUE) userdata;

    /* Get the pointer to the transfer: */
    ov_http_transfer_ptr(transfer, transfer_ptr);

    /* Check if the operation has been cancelled, and return immediately, this will cause the perform method to
       return an error to the caller: */
    if (transfer_ptr->cancel) {
        return CURL_READFUNC_ABORT;
    }

    /* Execute the read with the global interpreter lock acquired, as it needs to call Ruby methods: */
    context.ptr = ptr;
    context.size = size;
    context.nmemb = nmemb;
    context.io = transfer_ptr->in;
    rb_thread_call_with_gvl(ov_http_client_read_task, &context);
    return context.result;
}

static void* ov_http_client_write_task(void* data) {
    VALUE bytes;
    VALUE count;
    ov_http_client_io_context* context_ptr;

    /* The passed data is a pointer to the IO context: */
    context_ptr = (ov_http_client_io_context*) data;

    /* Convert the buffer to a Ruby string and write it to the IO object, using the "write" method: */
    bytes = rb_str_new(context_ptr->ptr, context_ptr->size * context_ptr->nmemb);
    count = rb_funcall(context_ptr->io, WRITE_ID, 1, bytes);
    context_ptr->result = NUM2INT(count);

    return NULL;
}

static size_t ov_http_client_write_function(char *ptr, size_t size, size_t nmemb, void *userdata) {
    VALUE transfer;
    ov_http_client_io_context context;
    ov_http_transfer_object* transfer_ptr;

    /* The passed user data is the transfer: */
    transfer = (VALUE) userdata;

    /* Get the pointer to the transfer: */
    ov_http_transfer_ptr(transfer, transfer_ptr);

    /* Check if the operation has been cancelled, and return immediately, this will cause the perform method to
       return an error to the caller: */
    if (transfer_ptr->cancel) {
        return 0;
    }

    /* Execute the write with the global interpreter lock acquired, as it needs to call Ruby methods: */
    context.ptr = ptr;
    context.size = size;
    context.nmemb = nmemb;
    context.io = transfer_ptr->out;
    rb_thread_call_with_gvl(ov_http_client_write_task, &context);
    return context.result;
}

static void* ov_http_client_header_task(void* data) {
    VALUE name;
    VALUE value;
    char* buffer;
    char* pointer;
    ov_http_client_header_context* context_ptr;
    ov_http_response_object* response_ptr;
    size_t length;

    /* The passed data is the pointer to the context: */
    context_ptr = (ov_http_client_header_context*) data;

    /* Get the pointer to the response: */
    ov_http_response_ptr(context_ptr->response, response_ptr);

    /* We should always tell the library that we processed all the data: */
    context_ptr->result = context_ptr->size * context_ptr->nitems;

    /* The library provides the headers for all the responses it receives, including the responses for intermediate
       requests used for authentication negotation. We are interested only in the headers of the last response, so
       if the given data is the begin of a new response, we clear the headers hash. */
    length = context_ptr->result;
    buffer = context_ptr->buffer;
    if (length >= 5 && strncmp("HTTP/", buffer, 5) == 0) {
        rb_hash_clear(response_ptr->headers);
        return NULL;
    }

    /* Remove trailing white space: */
    while (length > 0 && isspace(buffer[length - 1])) {
        length--;
    }

    /* Parse the header and add it to the response object: */
    pointer = memchr(buffer, ':', length);
    if (pointer != NULL) {
        name = rb_str_new(buffer, pointer - buffer);
        name = rb_funcall(name, DOWNCASE_ID, 0);
        pointer++;
        while (pointer - buffer < length && isspace(*pointer)) {
            pointer++;
        }
        value = rb_str_new(pointer, length - (pointer - buffer));
        rb_hash_aset(response_ptr->headers, name, value);
    }

    return NULL;
}

static size_t ov_http_client_header_function(char *buffer, size_t size, size_t nitems, void *userdata) {
    VALUE transfer;
    ov_http_client_header_context context;
    ov_http_transfer_object* transfer_ptr;

    /* The passed user data is a pointer to the transfer: */
    transfer = (VALUE) userdata;

    /* Get the pointer to the transfer: */
    ov_http_transfer_ptr(transfer, transfer_ptr);

    /* Check if the operation has been cancelled, and return immediately, this will cause the perform method to
       return an error to the caller: */
    if (transfer_ptr->cancel) {
        return 0;
    }

    /* Parse the header with the global interpreter lock acquired, as it needs to call Ruby methods: */
    context.response = transfer_ptr->response;
    context.buffer = buffer;
    context.size = size;
    context.nitems = nitems;
    rb_thread_call_with_gvl(ov_http_client_header_task, &context);
    return context.result;
}

static void* ov_http_client_debug_task(void* data) {
    VALUE line;
    VALUE log;
    char* text;
    int c;
    int s;
    ov_http_client_debug_context* context_ptr;
    ov_http_client_object* client_ptr;
    size_t i;
    size_t j;
    size_t size;

    /* The passed data is a pointer to the context: */
    context_ptr = (ov_http_client_debug_context*) data;

    /* Get the pointer to the client: */
    ov_http_client_ptr(context_ptr->client, client_ptr);

    /* Do nothing if there is no log: */
    log = client_ptr->log;
    if (NIL_P(log)) {
        return NULL;
    }

    /* Split the text into lines, and send a debug message for each line: */
    text = context_ptr->data;
    size = context_ptr->size;
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
    VALUE transfer;
    ov_http_client_debug_context context;
    ov_http_transfer_object* transfer_ptr;

    /* The passed user pointer is the transfer: */
    transfer = (VALUE) userptr;

    /* Get the pointer to the transfer: */
    ov_http_transfer_ptr(transfer, transfer_ptr);

    /* Execute the debug code with the global interpreter lock acquired, as it needs to call Ruby methods: */
    context.client = transfer_ptr->client;
    context.type = type;
    context.data = data;
    context.size = size;
    rb_thread_call_with_gvl(ov_http_client_debug_task, &context);
    return 0;
}

static VALUE ov_http_client_initialize(int argc, VALUE* argv, VALUE self) {
    VALUE opt;
    VALUE opts;
    long connections;
    long pipeline;
    ov_http_client_object* ptr;

    /* Get the pointer to the native object: */
    ov_http_client_ptr(self, ptr);

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

    /* Get the value of the 'ca_file' parameter: */
    opt = rb_hash_aref(opts, CA_FILE_SYMBOL);
    if (NIL_P(opt)) {
        ptr->ca_file = NULL;
    }
    else {
        Check_Type(opt, T_STRING);
        ptr->ca_file = ov_string_dup(opt);
    }

    /* Get the value of the 'insecure' parameter: */
    opt = rb_hash_aref(opts, INSECURE_SYMBOL);
    ptr->insecure = NIL_P(opt)? false: RTEST(opt);

    /* Get the value of the 'debug' parameter: */
    opt = rb_hash_aref(opts, DEBUG_SYMBOL);
    ptr->debug = NIL_P(opt)? false: RTEST(opt);

    /* Get the value of the 'compress' parameter: */
    opt = rb_hash_aref(opts, COMPRESS_SYMBOL);
    ptr->compress = NIL_P(opt)? true: RTEST(opt);

    /* Get the value of the 'timeout' parameter: */
    opt = rb_hash_aref(opts, TIMEOUT_SYMBOL);
    if (NIL_P(opt)) {
        ptr->timeout = 0;
    }
    else {
        Check_Type(opt, T_FIXNUM);
        ptr->timeout = NUM2INT(opt);
    }

    /* Get the value of the 'connect_timeout' parameter: */
    opt = rb_hash_aref(opts, CONNECT_TIMEOUT_SYMBOL);
    if (NIL_P(opt)) {
        ptr->connect_timeout = 0;
    }
    else {
        Check_Type(opt, T_FIXNUM);
        ptr->connect_timeout = NUM2INT(opt);
    }

    /* Get the value of the 'proxy_url' parameter: */
    opt = rb_hash_aref(opts, PROXY_URL_SYMBOL);
    if (NIL_P(opt)) {
        ptr->proxy_url = NULL;
    }
    else {
        Check_Type(opt, T_STRING);
        ptr->proxy_url = ov_string_dup(opt);
    }

    /* Get the value of the 'proxy_username' parameter: */
    opt = rb_hash_aref(opts, PROXY_USERNAME_SYMBOL);
    if (NIL_P(opt)) {
        ptr->proxy_username = NULL;
    }
    else {
        Check_Type(opt, T_STRING);
        ptr->proxy_username = ov_string_dup(opt);
    }

    /* Get the value of the 'proxy_password' parameter: */
    opt = rb_hash_aref(opts, PROXY_PASSWORD_SYMBOL);
    if (NIL_P(opt)) {
        ptr->proxy_password = NULL;
    }
    else {
        Check_Type(opt, T_STRING);
        ptr->proxy_password = ov_string_dup(opt);
    }

    /* Get the value of the 'log' parameter: */
    opt = rb_hash_aref(opts, LOG_SYMBOL);
    ptr->log = opt;

    /* Get the value of the 'pipeline' parameter: */
    opt = rb_hash_aref(opts, PIPELINE_SYMBOL);
    if (NIL_P(opt)) {
        pipeline = 0;
    }
    else {
        Check_Type(opt, T_FIXNUM);
        pipeline = NUM2LONG(opt);
    }
    if (pipeline < 0) {
        rb_raise(rb_eArgError, "The maximum pipeline length can't be %ld, minimum is 0.", pipeline);
    }

    /* Get the value of the 'connections' parameter: */
    opt = rb_hash_aref(opts, CONNECTIONS_SYMBOL);
    if (NIL_P(opt)) {
        connections = 1;
    }
    else {
        Check_Type(opt, T_FIXNUM);
        connections = NUM2LONG(opt);
    }
    if (connections < 1) {
        rb_raise(rb_eArgError, "The maximum number of connections can't be %ld, minimum is 1.", connections);
    }

   /* Get the value of the 'cookies' parameter. If it is a string it will be used as the path of the file where the
      cookies will be stored. If it is any other thing it will be treated as a boolean flag indicating if cookies
      should be enabled but not loaded/saved from/to any file. */
    opt = rb_hash_aref(opts, COOKIES_SYMBOL);
    if (TYPE(opt) == T_STRING) {
        ptr->cookies = ov_string_dup(opt);
    }
    else if (RTEST(opt)) {
        ptr->cookies = ov_string_dup(rb_str_new2(""));
    }
    else {
        ptr->cookies = NULL;
    }

    /* Create the queue that contains requests that haven't been sent to libcurl yet: */
    ptr->queue = rb_ary_new();

    /* Create the hash that contains the transfers are pending an completed. Both use the identity of the request
       as key. */
    ptr->completed = rb_funcall(rb_hash_new(), COMPARE_BY_IDENTITY_ID, 0);
    ptr->pending = rb_funcall(rb_hash_new(), COMPARE_BY_IDENTITY_ID, 0);

    /* Calculate the max number of requests that can be handled by libcurl simultaneously. For versions of libcurl
       newer than 7.30.0 the limit can be increased when using pipelining. For older versions it can't be increased
       because libcurl would create additional connections for the requests that can't be pipelined. */
    ptr->limit = connections;
    if (pipeline > 0 && libcurl_version->version_num >= 0x071e00 /* 7.30.0 */) {
        ptr->limit *= pipeline;
    }

    /* Create the libcurl multi handle: */
    ptr->handle = curl_multi_init();
    if (ptr->handle == NULL) {
        rb_raise(ov_error_class, "Can't create libcurl multi object");
    }

    /* Create the libcurl share handle in order to share cookie data: */
    ptr->share = curl_share_init();
    if (ptr->share == NULL) {
        rb_raise(ov_error_class, "Can't create libcurl share object");
    }
    if (ptr->cookies != NULL) {
        curl_share_setopt(ptr->share, CURLSHOPT_SHARE, CURL_LOCK_DATA_COOKIE);
    }

    /* Enable pipelining: */
    if (pipeline > 0) {
        curl_multi_setopt(ptr->handle, CURLMOPT_PIPELINING, CURLPIPE_HTTP1);
        if (libcurl_version->version_num >= 0x071e00 /* 7.30.0 */) {
            curl_multi_setopt(ptr->handle, CURLMOPT_MAX_PIPELINE_LENGTH, pipeline);
        }
        else {
            ov_http_client_log_warn(
                ptr->log,
                "Can't set maximum pipeline length to %d, it isn't supported by libcurl %s. Upgrade to 7.30.0 or "
                "newer to avoid this issue.",
                pipeline,
                libcurl_version->version
            );
        }
    }

    /* Set the max number of connections: */
    if (connections > 0) {
        if (libcurl_version->version_num >= 0x071e00 /* 7.30.0 */) {
            curl_multi_setopt(ptr->handle, CURLMOPT_MAX_HOST_CONNECTIONS, connections);
            curl_multi_setopt(ptr->handle, CURLMOPT_MAX_TOTAL_CONNECTIONS, connections);
        }
        else {
            ov_http_client_log_warn(
                ptr->log,
                "Can't set maximum number of connections to %d, it isn't supported by libcurl %s. Upgrade to 7.30.0 "
                "or newer to avoid this issue.",
                connections,
                libcurl_version->version
            );
        }
        if (libcurl_version->version_num >= 0x070f03 /* 7.16.3 */) {
            curl_multi_setopt(ptr->handle, CURLMOPT_MAXCONNECTS, connections);
        }
        else {
            ov_http_client_log_warn(
                ptr->log,
                "Can't set total maximum connection cache size to %d, it isn't supported by libcurl %s. Upgrade to "
                "7.16.3 or newer to avoid this issue.",
                connections,
                libcurl_version->version
            );
        }
    }

    return self;
}

static VALUE ov_http_client_build_url( VALUE url, VALUE query) {
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

static void* ov_http_client_complete_task(void* data) {
    CURLM* handle;
    CURLMsg* message;
    VALUE error_class;
    VALUE error_instance;
    VALUE transfer;
    long code;
    ov_http_client_object* client_ptr;
    ov_http_request_object* request_ptr;
    ov_http_response_object* response_ptr;
    ov_http_transfer_object* transfer_ptr;

    /* The passed pointer is the libcurl message describing the completed transfer: */
    message = (CURLMsg*) data;
    handle = message->easy_handle;

    /* The transfer is stored as the private data of the libcurl easy handle: */
    curl_easy_getinfo(handle, CURLINFO_PRIVATE, &transfer);

    /* Get the pointers to the transfer, client and response: */
    ov_http_transfer_ptr(transfer, transfer_ptr);
    ov_http_client_ptr(transfer_ptr->client, client_ptr);
    ov_http_request_ptr(transfer_ptr->request, request_ptr);
    ov_http_response_ptr(transfer_ptr->response, response_ptr);

    /* Remove the transfer from the pending hash: */
    rb_hash_delete(client_ptr->pending, transfer_ptr->request);

    if (message->data.result == CURLE_OK) {
        /* Copy the response code and the response body to the response object: */
        curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &code);
        response_ptr->code = LONG2NUM(code);
        response_ptr->body = rb_funcall(transfer_ptr->out, STRING_ID, 0);

        /* Put the request and the response in the completed transfers hash: */
        rb_hash_aset(client_ptr->completed, transfer_ptr->request, transfer_ptr->response);

        /* Send a summary of the response to the log: */
        ov_http_client_log_info(
            client_ptr->log,
            "Received response code %"PRIsVALUE" for %"PRIsVALUE" request to URL '%"PRIsVALUE"'.",
            response_ptr->code,
            request_ptr->method,
            request_ptr->url
        );
    }
    else {
        /* Select the error class according to the kind of error returned by libcurl: */
        switch (message->data.result) {
        case CURLE_COULDNT_CONNECT:
        case CURLE_COULDNT_RESOLVE_HOST:
        case CURLE_COULDNT_RESOLVE_PROXY:
            error_class = ov_connection_error_class;
            break;
        case CURLE_OPERATION_TIMEDOUT:
            error_class = ov_timeout_error_class;
            break;
        default:
            error_class = ov_error_class;
        }

        /* Put the request and error in the completed transfers hash: */
        error_instance = rb_sprintf("Can't send request: %s", curl_easy_strerror(message->data.result));
        error_instance = rb_class_new_instance(1, &error_instance, error_class);
        rb_hash_aset(client_ptr->completed, transfer_ptr->request, error_instance);
    }

    /* Now that the libcurl easy handle is released, we can release the headers as well: */
    curl_slist_free_all(transfer_ptr->headers);

    return NULL;
}

static void* ov_http_client_wait_task(void* data) {
    CURLMsg* message;
    int count;
    int pending;
    long timeout;
    ov_http_client_wait_context* context_ptr;
#if LIBCURL_VERSION_NUM < 0x071c00
    fd_set fd_read;
    fd_set fd_write;
    fd_set fd_error;
    int fd_count;
    struct timeval tv;
#endif

    /* The passed data is the wait context: */
    context_ptr = data;

    /* Get the timeout preferred by libcurl, or one 100 ms by default: */
    curl_multi_timeout(context_ptr->handle, &timeout);
    if (timeout < 0) {
        timeout = 100;
    }

#if LIBCURL_VERSION_NUM >= 0x071c00
    /* Wait till there is activity: */
    context_ptr->code = curl_multi_wait(context_ptr->handle, NULL, 0, timeout, NULL);
    if (context_ptr->code != CURLE_OK) {
        return NULL;
    }
#else
    /* Versions of libcurl older than 7.28.0 don't provide the 'curl_multi_wait' function, so we need to get the file
       descriptors used by libcurl, and explicitly use the 'select' system call: */
    FD_ZERO(&fd_read);
    FD_ZERO(&fd_write);
    FD_ZERO(&fd_error);
    context_ptr->code = curl_multi_fdset(context_ptr->handle, &fd_read, &fd_write, &fd_error, &fd_count);
    if (context_ptr->code != CURLE_OK) {
        return NULL;
    }
    tv.tv_sec = timeout / 1000;
    tv.tv_usec = (timeout % 1000) * 1000;
    select(fd_count + 1, &fd_read, &fd_write, &fd_error, &tv);
#endif

    /* Let libcurl do its work, even if no file descriptor needs attention. This is necessary because some of its
       activities can't be monitored using file descriptors. */
    context_ptr->code = curl_multi_perform(context_ptr->handle, &pending);
    if (context_ptr->code != CURLE_OK) {
        return NULL;
    }

    /* Check if there are finished transfers. For each of them call the function that completes them, with the global
       interpreter lock acquired, as it will call Ruby code. */
    while ((message = curl_multi_info_read(context_ptr->handle, &count)) != NULL) {
        if (message->msg == CURLMSG_DONE) {
            /* Call the Ruby code that completes the transfer: */
            rb_thread_call_with_gvl(ov_http_client_complete_task, message);

            /* Remove the easy handle from the multi handle and discard it: */
            curl_multi_remove_handle(context_ptr->handle, message->easy_handle);
            curl_easy_cleanup(message->easy_handle);
        }
    }

    /* Everything worked correctly: */
    context_ptr->code = CURLE_OK;
    return NULL;
}

static void ov_http_client_wait_cancel(void* data) {
    ov_http_client_wait_context* context_ptr;

    /* The passed data is the wait context: */
    context_ptr = data;

    /* Set the cancel flag so that the operation will be actually aborted in the next operation of the wait loop: */
    context_ptr->cancel = true;
}

static void ov_http_client_prepare_handle(ov_http_client_object* client_ptr, ov_http_request_object* request_ptr,
        struct curl_slist** headers, CURL* handle) {
    VALUE header;
    VALUE url;
    int timeout;
    int connect_timeout;

    /* Configure sharing of cookies with other handlers created by the client: */
    curl_easy_setopt(handle, CURLOPT_SHARE, client_ptr->share);
    if (client_ptr->cookies != NULL && strlen(client_ptr->cookies) > 0) {
        curl_easy_setopt(handle, CURLOPT_COOKIEFILE, client_ptr->cookies);
        curl_easy_setopt(handle, CURLOPT_COOKIEJAR, client_ptr->cookies);
    }

    /* Configure TLS parameters: */
    if (client_ptr->insecure) {
        curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER, 0L);
        curl_easy_setopt(handle, CURLOPT_SSL_VERIFYHOST, 0L);
    }
    if (client_ptr->ca_file != NULL) {
        curl_easy_setopt(handle, CURLOPT_CAINFO, client_ptr->ca_file);
    }

    /* Configure the total timeout: */
    timeout = client_ptr->timeout;
    if (!NIL_P(request_ptr->timeout)) {
        timeout = NUM2INT(request_ptr->timeout);
    }
    curl_easy_setopt(handle, CURLOPT_TIMEOUT, timeout);

    /* Configure the connect timeout: */
    connect_timeout = client_ptr->connect_timeout;
    if (!NIL_P(request_ptr->connect_timeout)) {
        connect_timeout = NUM2INT(request_ptr->connect_timeout);
    }
    curl_easy_setopt(handle, CURLOPT_CONNECTTIMEOUT, connect_timeout);

    /* Configure compression of responses (setting the value to zero length string means accepting all the
       compression types that libcurl supports): */
    if (client_ptr->compress) {
        curl_easy_setopt(handle, CURLOPT_ENCODING, "");
    }

    /* Configure debug mode: */
    if (client_ptr->debug) {
        curl_easy_setopt(handle, CURLOPT_VERBOSE, 1L);
        curl_easy_setopt(handle, CURLOPT_DEBUGFUNCTION, ov_http_client_debug_function);
    }

    /* Configure the proxy: */
    if (client_ptr->proxy_url != NULL) {
        curl_easy_setopt(handle, CURLOPT_PROXY, client_ptr->proxy_url);
        if (client_ptr->proxy_username != NULL && client_ptr->proxy_password != NULL) {
            curl_easy_setopt(handle, CURLOPT_PROXYUSERNAME, client_ptr->proxy_username);
            curl_easy_setopt(handle, CURLOPT_PROXYPASSWORD, client_ptr->proxy_password);
        }
    }

    /* Configure callbacks: */
    curl_easy_setopt(handle, CURLOPT_READFUNCTION, ov_http_client_read_function);
    curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, ov_http_client_write_function);
    curl_easy_setopt(handle, CURLOPT_HEADERFUNCTION, ov_http_client_header_function);

    /* Build and set the URL: */
    url = ov_http_client_build_url(request_ptr->url, request_ptr->query);
    curl_easy_setopt(handle, CURLOPT_URL, StringValueCStr(url));

    /* Set the method: */
    if (rb_eql(request_ptr->method, POST_SYMBOL)) {
       *headers = curl_slist_append(*headers, "Transfer-Encoding: chunked");
       *headers = curl_slist_append(*headers, "Expect:");
       curl_easy_setopt(handle, CURLOPT_POST, 1L);
    }
    else if (rb_eql(request_ptr->method, PUT_SYMBOL)) {
       *headers = curl_slist_append(*headers, "Expect:");
       curl_easy_setopt(handle, CURLOPT_UPLOAD, 1L);
       curl_easy_setopt(handle, CURLOPT_PUT, 1L);
    }
    else if (rb_eql(request_ptr->method, DELETE_SYMBOL)) {
       curl_easy_setopt(handle, CURLOPT_HTTPGET, 1L);
       curl_easy_setopt(handle, CURLOPT_CUSTOMREQUEST, "DELETE");
    }
    else if (rb_eql(request_ptr->method, GET_SYMBOL)) {
       curl_easy_setopt(handle, CURLOPT_HTTPGET, 1L);
    }

    /* Set authentication details: */
    if (!NIL_P(request_ptr->token)) {
        header = rb_sprintf("Authorization: Bearer %"PRIsVALUE"", request_ptr->token);
        *headers = curl_slist_append(*headers, StringValueCStr(header));
    }
    else if (!NIL_P(request_ptr->username) && !NIL_P(request_ptr->password)) {
        curl_easy_setopt(handle, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
        curl_easy_setopt(handle, CURLOPT_USERNAME, StringValueCStr(request_ptr->username));
        curl_easy_setopt(handle, CURLOPT_PASSWORD, StringValueCStr(request_ptr->password));
    }
    else if (RTEST(request_ptr->kerberos)) {
        curl_easy_setopt(handle, CURLOPT_HTTPAUTH, CURLAUTH_NEGOTIATE);
    }

    /* Set the headers: */
    if (!NIL_P(request_ptr->headers)) {
        rb_hash_foreach(request_ptr->headers, ov_http_client_add_header, (VALUE) headers);
    }
    curl_easy_setopt(handle, CURLOPT_HTTPHEADER, *headers);

    /* Send a summary of the request to the log: */
    ov_http_client_log_info(
        client_ptr->log,
        "Sending %"PRIsVALUE" request to URL '%"PRIsVALUE"'.",
        request_ptr->method,
        url
    );
}

static VALUE ov_http_client_submit(VALUE self, VALUE request) {
    CURL* handle;
    VALUE response;
    VALUE transfer;
    ov_http_client_object* ptr;
    ov_http_request_object* request_ptr;
    ov_http_transfer_object* transfer_ptr;
    struct curl_slist* headers;

    /* Get the pointer to the native object and check that it isn't closed: */
    ov_http_client_ptr(self, ptr);
    ov_http_client_check_closed(ptr);

    /* Check the type of request and get the pointer to the native object: */
    if (NIL_P(request)) {
        rb_raise(ov_error_class, "The 'request' parameter can't be nil");
    }
    if (!rb_obj_is_instance_of(request, ov_http_request_class)) {
        rb_raise(ov_error_class, "The 'request' parameter isn't an instance of class 'HttpRequest'");
    }
    ov_http_request_ptr(request, request_ptr);

    /* Create the libcurl easy handle: */
    handle = curl_easy_init();
    if (ptr->handle == NULL) {
        rb_raise(ov_error_class, "Can't create libcurl object");
    }

    /* The headers used by the libcurl easy handle can't be released till the handle is released itself, so we need
       to initialize here, and add it to the context so that we can release it later: */
    headers = NULL;

    /* Configure the libcurl easy handle with the data from the client and from the request: */
    ov_http_client_prepare_handle(ptr, request_ptr, &headers, handle);

    /* Allocate a ne empty response: */
    response = rb_class_new_instance(0, NULL, ov_http_response_class);

    /* Allocate a new empty transfer: */
    transfer = rb_class_new_instance(0, NULL, ov_http_transfer_class);
    ov_http_transfer_ptr(transfer, transfer_ptr);
    transfer_ptr->client = self;
    transfer_ptr->request = request;
    transfer_ptr->response = response;
    transfer_ptr->headers = headers;
    transfer_ptr->cancel = false;
    if (NIL_P(request_ptr->body)) {
        transfer_ptr->in = rb_class_new_instance(0, NULL, STRING_IO_CLASS);
    }
    else {
        transfer_ptr->in = rb_class_new_instance(1, &request_ptr->body, STRING_IO_CLASS);
    }
    transfer_ptr->out = rb_class_new_instance(0, NULL, STRING_IO_CLASS);

    /* Put the request and the transfer in the hash of pending transfers: */
    rb_hash_aset(ptr->pending, request, transfer);

    /* Set the transfer as the data for all the callbacks, so we can access it from any place where it is needed: */
    curl_easy_setopt(handle, CURLOPT_PRIVATE, transfer);
    curl_easy_setopt(handle, CURLOPT_READDATA, transfer);
    curl_easy_setopt(handle, CURLOPT_WRITEDATA, transfer);
    curl_easy_setopt(handle, CURLOPT_HEADERDATA, transfer);
    curl_easy_setopt(handle, CURLOPT_DEBUGDATA, transfer);

    /* Add the easy handle to the multi handle: */
    curl_multi_add_handle(ptr->handle, handle);

    return Qnil;
}

static VALUE ov_http_client_send(VALUE self, VALUE request) {
    ov_http_client_object* ptr;

    /* Get the pointer to the native object and check that it isn't closed: */
    ov_http_client_ptr(self, ptr);
    ov_http_client_check_closed(ptr);

    /* If the limit hasn't been reached then submit the request directly to libcurl, otherwise put it in the queue: */
    if (RHASH_SIZE(ptr->pending) < ptr->limit) {
        ov_http_client_submit(self, request);
    }
    else {
        rb_ary_push(ptr->queue, request);
    }

    return Qnil;
}

static VALUE ov_http_client_wait(VALUE self, VALUE request) {
    VALUE next;
    VALUE result;
    ov_http_client_object* ptr;
    ov_http_client_wait_context context;

    /* Get the pointer to the native object and check that it isn't closed: */
    ov_http_client_ptr(self, ptr);
    ov_http_client_check_closed(ptr);

    /* Work till the transfer has been completed. */
    context.handle = ptr->handle;
    context.code = CURLE_OK;
    context.cancel = false;
    for (;;) {
        /* Move requests from the queue to libcurl: */
        while (RARRAY_LEN(ptr->queue) > 0 && RHASH_SIZE(ptr->pending) < ptr->limit) {
            next = rb_ary_shift(ptr->queue);
            ov_http_client_submit(self, next);
        }

        /* Check if the response is already available, if so then return it: */
        result = rb_hash_delete(ptr->completed, request);
        if (!NIL_P(result)) {
            return result;
        }

        /* If the response isn't available yet, then do some real work: */
        rb_thread_call_without_gvl(
            ov_http_client_wait_task,
            &context,
            ov_http_client_wait_cancel,
            &context
        );
        if (context.cancel) {
            return Qnil;
        }
        if (context.code != CURLE_OK) {
            rb_raise(ov_error_class, "Unexpected error while waiting: %s", curl_easy_strerror(context.code));
        }
    }

    return Qnil;
}

static VALUE ov_http_client_inspect(VALUE self) {
    ov_http_client_object* ptr;

    ov_http_client_ptr(self, ptr);
    return rb_sprintf("#<%"PRIsVALUE":%p>", ov_http_client_class, ptr);
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
    rb_define_method(ov_http_client_class, "close",   ov_http_client_close,   0);
    rb_define_method(ov_http_client_class, "inspect", ov_http_client_inspect, 0);
    rb_define_method(ov_http_client_class, "send",    ov_http_client_send,    1);
    rb_define_method(ov_http_client_class, "to_s",    ov_http_client_inspect, 0);
    rb_define_method(ov_http_client_class, "wait",    ov_http_client_wait,    1);

    /* Define the symbols: */
    CA_FILE_SYMBOL         = ID2SYM(rb_intern("ca_file"));
    COMPRESS_SYMBOL        = ID2SYM(rb_intern("compress"));
    CONNECTIONS_SYMBOL     = ID2SYM(rb_intern("connections"));
    DEBUG_SYMBOL           = ID2SYM(rb_intern("debug"));
    INSECURE_SYMBOL        = ID2SYM(rb_intern("insecure"));
    LOG_SYMBOL             = ID2SYM(rb_intern("log"));
    PASSWORD_SYMBOL        = ID2SYM(rb_intern("password"));
    PIPELINE_SYMBOL        = ID2SYM(rb_intern("pipeline"));
    PROXY_PASSWORD_SYMBOL  = ID2SYM(rb_intern("proxy_password"));
    PROXY_URL_SYMBOL       = ID2SYM(rb_intern("proxy_url"));
    PROXY_USERNAME_SYMBOL  = ID2SYM(rb_intern("proxy_username"));
    TIMEOUT_SYMBOL         = ID2SYM(rb_intern("timeout"));
    CONNECT_TIMEOUT_SYMBOL = ID2SYM(rb_intern("connect_timeout"));
    COOKIES_SYMBOL         = ID2SYM(rb_intern("cookies"));

    /* Define the method identifiers: */
    COMPARE_BY_IDENTITY_ID = rb_intern("compare_by_identity");
    DEBUG_ID               = rb_intern("debug");
    DOWNCASE_ID            = rb_intern("downcase");
    ENCODE_WWW_FORM_ID     = rb_intern("encode_www_form");
    INFO_ID                = rb_intern("info");
    INFO_Q_ID              = rb_intern("info?");
    READ_ID                = rb_intern("read");
    STRING_ID              = rb_intern("string");
    STRING_IO_ID           = rb_intern("StringIO");
    URI_ID                 = rb_intern("URI");
    WARN_ID                = rb_intern("warn");
    WARN_Q_ID              = rb_intern("warn?");
    WRITE_ID               = rb_intern("write");

    /* Locate classes: */
    STRING_IO_CLASS = rb_const_get(rb_cObject, STRING_IO_ID);
    URI_CLASS       = rb_const_get(rb_cObject, URI_ID);

    /* Initialize libcurl: */
    code = curl_global_init(CURL_GLOBAL_DEFAULT);
    if (code != CURLE_OK) {
        rb_raise(ov_error_class, "Can't initialize libcurl: %s", curl_easy_strerror(code));
    }

    /* Get the libcurl version: */
    libcurl_version = curl_version_info(CURLVERSION_NOW);
}
