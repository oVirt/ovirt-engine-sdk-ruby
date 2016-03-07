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

package org.ovirt.sdk.ruby;

import javax.enterprise.context.ApplicationScoped;
import javax.inject.Inject;

import org.ovirt.api.metamodel.concepts.EnumType;
import org.ovirt.api.metamodel.concepts.ListType;
import org.ovirt.api.metamodel.concepts.Model;
import org.ovirt.api.metamodel.concepts.PrimitiveType;
import org.ovirt.api.metamodel.concepts.StructType;
import org.ovirt.api.metamodel.concepts.Type;

/**
 * This class contains methods used to generate Yard documentation.
 */
@ApplicationScoped
public class YardDoc {
    // Reference to the object used to calculate Ruby names:
    @Inject
    private RubyNames rubyNames;

    /**
     * Generates the type string used in Yard documentation.
     */
    public String getType(Type type) {
        if (type instanceof PrimitiveType) {
            Model model = type.getModel();
            if (type == model.getBooleanType()) {
                return "Boolean";
            }
            if (type == model.getIntegerType()) {
                return "Integer";
            }
            if (type == model.getDecimalType()) {
                return "Fixnum";
            }
            if (type == model.getStringType()) {
                return "String";
            }
            if (type == model.getDateType()) {
                return "DateTime";
            }
            throw new RuntimeException("Don't know how to calculate the Yard type for primitive type \"" + type + "\"");
        }
        if (type instanceof EnumType || type instanceof StructType) {
            return rubyNames.getClassStyleName(type.getName());
        }
        if (type instanceof ListType) {
            ListType listType = (ListType) type;
            Type elementType = listType.getElementType();
            return String.format("Array<%1$s>", getType(elementType));
        }
        throw new RuntimeException("Don't know how to calculate the Yard type for type \"" + type + "\"");
    }
}

