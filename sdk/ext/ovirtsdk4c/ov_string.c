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
#include <string.h>

#include "ov_string.h"

char* ov_string_dup(VALUE str) {
    long len = 0;
    char* raw = NULL;
    char* ptr = NULL;

    if (!NIL_P(str)) {
        Check_Type(str, T_STRING);
        len = RSTRING_LEN(str);
        raw = RSTRING_PTR(str);
        ptr = (char*) ALLOC_N(char, len + 1);
        strncpy(ptr, raw, len);
        ptr[len] = '\0';
    }
    return ptr;
}

void ov_string_free(char* ptr) {
    if (ptr != NULL) {
        xfree(ptr);
    }
}

