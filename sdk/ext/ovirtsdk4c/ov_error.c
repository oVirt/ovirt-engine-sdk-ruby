/*
Copyright (c) 2015-2017 Red Hat, Inc.

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

/* Classes: */
VALUE ov_error_class;
VALUE ov_connection_error_class;
VALUE ov_timeout_error_class;

void ov_error_define(void) {
    /* Define the base error class: */
    ov_error_class = rb_define_class_under(ov_module, "Error", rb_eStandardError);

    /* Define the specialized error classes: */
    ov_connection_error_class = rb_define_class_under(ov_module, "ConnectionError", ov_error_class);
    ov_timeout_error_class = rb_define_class_under(ov_module, "TimeoutError", ov_error_class);
}
