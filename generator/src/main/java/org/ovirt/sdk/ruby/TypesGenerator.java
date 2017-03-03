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

package org.ovirt.sdk.ruby;

import static java.util.stream.Collectors.toCollection;

import java.io.File;
import java.io.IOException;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.List;
import javax.enterprise.inject.spi.CDI;
import javax.inject.Inject;

import org.ovirt.api.metamodel.concepts.EnumType;
import org.ovirt.api.metamodel.concepts.EnumValue;
import org.ovirt.api.metamodel.concepts.ListType;
import org.ovirt.api.metamodel.concepts.Model;
import org.ovirt.api.metamodel.concepts.Name;
import org.ovirt.api.metamodel.concepts.PrimitiveType;
import org.ovirt.api.metamodel.concepts.StructMember;
import org.ovirt.api.metamodel.concepts.StructType;
import org.ovirt.api.metamodel.concepts.Type;
import org.ovirt.api.metamodel.tool.Names;

/**
 * This class is responsible for generating the classes that represent the types of the model.
 */
public class TypesGenerator implements RubyGenerator {
    // The directory were the output will be generated:
    protected File out;

    // Reference to the objects used to generate the code:
    @Inject private Names names;
    @Inject private RubyNames rubyNames;
    @Inject private YardDoc yardDoc;

    // The buffer used to generate the Ruby code:
    private RubyBuffer buffer;

    public void setOut(File newOut) {
        out = newOut;
    }

    public void generate(Model model) {
        // Calculate the file name:
        String fileName = rubyNames.getModulePath() + "/types";
        buffer = CDI.current().select(RubyBuffer.class).get();
        buffer.setFileName(fileName);

        // Begin module:
        buffer.beginModule(rubyNames.getModuleName());
        buffer.addLine();

        // Generate the source:
        generateStructs(model);
        generateEnums(model);

        // End module:
        buffer.endModule(rubyNames.getModuleName());
        buffer.addLine();

        // Write the file:
        try {
            buffer.write(out);
        }
        catch (IOException exception) {
            throw new IllegalStateException("Error writing types file \"" + fileName + "\"", exception);
        }
    }

    private void generateStructs(Model model) {
        // Begin module:
        buffer.addComment();
        buffer.addComment("These forward declarations are required in order to avoid circular dependencies.");
        buffer.addComment();

        // The declarations of the types need to appear in inheritance order, otherwise some symbols won't be
        // defined and that will produce errors. To order them correctly we need first to sort them by name, and
        // then sort again so that bases are before extensions.
        Deque<StructType> pending = model.types()
            .filter(StructType.class::isInstance)
            .map(StructType.class::cast)
            .sorted()
            .collect(toCollection(ArrayDeque::new));
        Deque<StructType> sorted = new ArrayDeque<>(pending.size());
        while (!pending.isEmpty()) {
            StructType current = pending.removeFirst();
            StructType base = (StructType) current.getBase();
            if (base == null || sorted.contains(base)) {
                sorted.addLast(current);
            }
            else {
                pending.addLast(current);
            }
        }

        // Generate the forward declarations using the order calculated in the previous step:
        sorted.forEach(x -> {
            generateClassDeclaration(x);
            buffer.addLine("end");
            buffer.addLine();
        });

        // Generate the complete declarations, using the same order:
        sorted.forEach(this::generateStruct);
    }

    private void generateStruct(StructType type) {
        // Begin class:
        generateClassDeclaration(type);
        buffer.addLine();

        // Get the list of members, including those declared in the base types:
        List<StructMember> allMembers = new ArrayList<>();
        allMembers.addAll(type.getAttributes());
        allMembers.addAll(type.getLinks());
        Collections.sort(allMembers);

        // Get the list of members declared directly in this type:
        List<StructMember> declaredMembers = new ArrayList<>();
        declaredMembers.addAll(type.getDeclaredAttributes());
        declaredMembers.addAll(type.getDeclaredLinks());
        Collections.sort(declaredMembers);

        // Generate getters and setters, only for members declared directly in this class:
        allMembers.forEach(this::generateMember);

        // The constructor should have documentation for all the parameters, including those of the base types, but the
        // code only needs to handle the members declared in this type, as the others are handled by the constructor of
        // the base class:
        RubyName typeName = rubyNames.getTypeName(type);
        buffer.addComment();
        buffer.addComment("Creates a new instance of the {%1$s} class.", typeName.getClassName());
        buffer.addComment();
        buffer.addYardTag(
            "param",
            "opts [Hash] A hash containing the attributes of the object. The keys of the hash\n" +
            "should be symbols corresponding to the names of the attributes. The values of the hash\n" +
            "should be the values of the attributes."
        );
        buffer.addComment();
        allMembers.forEach(member -> {
            Type memberType = member.getType();
            Name memberName = member.getName();
            String docType = yardDoc.getType(memberType);
            String docName = rubyNames.getMemberStyleName(memberName);
            if (memberType instanceof PrimitiveType || memberType instanceof EnumType) {
                buffer.addYardTag("option", "opts [%1$s] :%2$s The value of attribute `%2$s`.", docType, docName);
                buffer.addComment();
            }
            else if (memberType instanceof StructType) {
                buffer.addYardTag("option", "opts [%1$s, Hash] :%2$s The value of attribute `%2$s`.", docType, docName);
                buffer.addComment();
            }
            else if (memberType instanceof ListType) {
                buffer.addYardTag("option", "opts [%1$s, Array<Hash>] :%2$s The values of attribute `%2$s`.", docType, docName);
                buffer.addComment();
            }
        });
        buffer.addComment();
        buffer.addLine("def initialize(opts = {})");
        buffer.addLine(  "super(opts)");
        declaredMembers.forEach(member -> {
            String memberName = rubyNames.getMemberStyleName(member.getName());
            buffer.addLine("self.%1$s = opts[:%1$s]", memberName);
        });
        buffer.addLine("end");
        buffer.addLine();

        // Operator to compare two objects:
        if (!declaredMembers.isEmpty()) {
            buffer.addComment();
            buffer.addComment("Returns `true` if `self` and `other` have the same attributes and values.");
            buffer.addComment();
            buffer.addLine("def ==(other)");
            buffer.addLine(  "super &&");
            for (int i = 0; i < declaredMembers.size(); i++) {
                String memberName = rubyNames.getMemberStyleName(declaredMembers.get(i).getName());
                String line = String.format("@%1$s == other.%1$s", memberName);
                if (i < declaredMembers.size() - 1) {
                    line += " &&";
                }
                buffer.addLine(line);
            }
            buffer.addLine("end");
            buffer.addLine();
        }

        // Method to calculate the hash code:
        if (!declaredMembers.isEmpty()) {
            buffer.addComment();
            buffer.addComment("Generates a hash value for this object.");
            buffer.addComment();
            buffer.addLine("def hash");
            buffer.addLine(  "super +");
            for (int i = 0; i < declaredMembers.size(); i++) {
                String memberName = rubyNames.getMemberStyleName(declaredMembers.get(i).getName());
                String line = String.format("@%1$s.hash", memberName);
                if (i < declaredMembers.size() - 1) {
                    line += " +";
                }
                buffer.addLine(line);
            }
            buffer.addLine("end");
            buffer.addLine();
        }

        // End class:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateMember(StructMember member) {
        generateGetter(member);
        generateSetter(member);
    }

    private void generateGetter(StructMember member) {
        Name name = member.getName();
        Type type = member.getType();
        String property = rubyNames.getMemberStyleName(name);
        buffer.addComment();
        buffer.addComment("Returns the value of the `%1$s` attribute.", property);
        buffer.addComment();
        buffer.addYardTag("return", "[%1$s]", yardDoc.getType(type));
        buffer.addComment();
        buffer.addLine("def %1$s", property);
        buffer.addLine(  "@%1$s", property);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateSetter(StructMember member) {
        Name name = member.getName();
        Type type = member.getType();
        String property = rubyNames.getMemberStyleName(name);
        buffer.addComment();
        buffer.addComment("Sets the value of the `%1$s` attribute.", property);
        buffer.addComment();
        if (type instanceof PrimitiveType || type instanceof EnumType) {
            buffer.addYardTag("param", "value [%1$s]", yardDoc.getType(type));
            buffer.addComment();
            buffer.addLine("def %1$s=(value)", property);
            buffer.addLine(  "@%1$s = value", property);
            buffer.addLine("end");
        }
        else if (type instanceof StructType) {
            RubyName typeName = rubyNames.getTypeName(type);
            buffer.addYardTag("param", "value [%1$s, Hash]", yardDoc.getType(type));
            buffer.addComment();
            buffer.addComment("The `value` parameter can be an instance of {%1$s} or a hash.", typeName);
            buffer.addComment("If it is a hash then a new instance will be created passing the hash as the ");
            buffer.addComment("`opts` parameter to the constructor.");
            buffer.addComment();
            buffer.addLine("def %1$s=(value)", property);
            buffer.addLine(  "if value.is_a?(Hash)");
            buffer.addLine(    "value = %1$s.new(value)", typeName.getClassName());
            buffer.addLine(  "end");
            buffer.addLine(  "@%1$s = value", property);
            buffer.addLine("end");
        }
        else if (type instanceof ListType) {
            buffer.addYardTag("param", "list [%1$s]", yardDoc.getType(type));
            buffer.addComment();
            ListType listType = (ListType) type;
            Type elementType = listType.getElementType();
            if (elementType instanceof PrimitiveType || elementType instanceof EnumType) {
                buffer.addLine("def %1$s=(list)", property);
                buffer.addLine(  "@%1$s = list", property);
                buffer.addLine("end");
            }
            else if (elementType instanceof StructType) {
                RubyName elementTypeName = rubyNames.getTypeName(elementType);
                buffer.addLine("def %1$s=(list)", property);
                buffer.addLine(  "if list.class == Array");
                buffer.addLine(    "list = List.new(list)");
                buffer.addLine(    "list.each_with_index do |value, index|");
                buffer.addLine(      "if value.is_a?(Hash)");
                buffer.addLine(        "list[index] = %1$s.new(value)", elementTypeName.getClassName());
                buffer.addLine(      "end");
                buffer.addLine(    "end");
                buffer.addLine(  "end");
                buffer.addLine(  "@%1$s = list", property);
                buffer.addLine("end");
            }
        }
        buffer.addLine();
    }

    private void generateEnums(Model model) {
        model.types()
            .filter(EnumType.class::isInstance)
            .map(EnumType.class::cast)
            .sorted()
            .forEach(this::generateEnum);
    }

    private void generateEnum(EnumType type) {
        // Begin module:
        RubyName typeName = rubyNames.getTypeName(type);
        buffer.beginModule(typeName.getClassName());

        // Values:
        type.values().sorted().forEach(this::generateEnumValue);

        // End module:
        buffer.endModule(typeName.getClassName());
        buffer.addLine();
    }

    private void generateEnumValue(EnumValue value) {
        Name name = value.getName();
        String constantName = rubyNames.getConstantStyleName(name);
        String constantValue = names.getLowerJoined(name, "_");
        buffer.addLine("%s = '%s'.freeze", constantName, constantValue);
    }

    private void generateClassDeclaration(StructType type) {
        RubyName typeName = rubyNames.getTypeName(type);
        Type base = type.getBase();
        RubyName baseName = base != null? rubyNames.getTypeName(base): rubyNames.getBaseStructName();
        buffer.addLine("class %1$s < %2$s", typeName.getClassName(), baseName.getClassName());
    }
}

