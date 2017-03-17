/*
Copyright (c) 2015-2016 Red Hat, Inc.

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
#include "ov_http_client.h"
#include "ov_http_request.h"
#include "ov_http_response.h"
#include "ov_http_transfer.h"
#include "ov_xml_reader.h"
#include "ov_xml_writer.h"

void Init_ovirtsdk4c(void) {
    /* Define the module: */
    ov_module_define();

    /* Define the classes: */
    ov_error_define();
    ov_http_client_define();
    ov_http_request_define();
    ov_http_response_define();
    ov_http_transfer_define();
    ov_xml_reader_define();
    ov_xml_writer_define();
}
