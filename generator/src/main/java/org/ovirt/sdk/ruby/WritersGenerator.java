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

package org.ovirt.sdk.ruby;

import java.io.File;
import java.io.IOException;
import javax.inject.Inject;

import org.ovirt.api.metamodel.concepts.EnumType;
import org.ovirt.api.metamodel.concepts.ListType;
import org.ovirt.api.metamodel.concepts.Model;
import org.ovirt.api.metamodel.concepts.Name;
import org.ovirt.api.metamodel.concepts.PrimitiveType;
import org.ovirt.api.metamodel.concepts.StructMember;
import org.ovirt.api.metamodel.concepts.StructType;
import org.ovirt.api.metamodel.concepts.Type;
import org.ovirt.api.metamodel.tool.Names;
import org.ovirt.api.metamodel.tool.SchemaNames;

/**
 * This class is responsible for generating the classes that take instances of model types and generate the
 * corresponding XML documents.
 */
public class WritersGenerator implements RubyGenerator {
    // The directory were the output will be generated:
    protected File out;

    // Reference to the objects used to generate the code:
    @Inject private Names names;
    @Inject private SchemaNames schemaNames;
    @Inject private RubyNames rubyNames;

    // The buffer used to generate the Ruby code:
    private RubyBuffer buffer;

    public void setOut(File newOut) {
        out = newOut;
    }

    public void generate(Model model) {
        // Calculate the file name:
        String fileName = rubyNames.getModulePath() + "/writers";
        buffer = new RubyBuffer();
        buffer.setFileName(fileName);

        // Generate the source:
        generateSource(model);

        // Write the file:
        try {
            buffer.write(out);
        }
        catch (IOException exception) {
            throw new IllegalStateException("Error writing writers file \"" + fileName + "\"", exception);
        }
    }

    private void generateSource(Model model) {
        // Begin module:
        String moduleName = rubyNames.getModuleName();
        buffer.beginModule(moduleName);
        buffer.addLine();

        // Generate a writer for each struct type:
        model.types()
            .filter(StructType.class::isInstance)
            .map(StructType.class::cast)
            .sorted()
            .forEach(this::generateWriter);

        // End module:
        buffer.endModule(moduleName);
    }

    private void generateWriter(StructType type) {
        // Begin class:
        RubyName writerName = rubyNames.getWriterName(type);
        RubyName baseName = rubyNames.getBaseWriterName();
        buffer.addLine("class %1$s < %2$s # :nodoc:", writerName.getClassName(), baseName.getClassName());
        buffer.addLine();

        // Get the tags:
        Name singularName = type.getName();
        Name pluralName = names.getPlural(singularName);

        // Generate the method that writes one object:
        buffer.addLine("def self.write_one(object, writer, singular = nil)");
        buffer.addLine(  "singular ||= '%1$s'", singularName);
        buffer.addLine(  "writer.write_start(singular)");
        buffer.addLine(  "href = object.href");
        buffer.addLine(  "writer.write_attribute('href', href) unless href.nil?");
        generateMembersWrite(type);
        buffer.addLine(  "writer.write_end");
        buffer.addLine("end");
        buffer.addLine();

        // Generate the method that writes one object:
        buffer.addLine("def self.write_many(list, writer, singular = nil, plural = nil)");
        buffer.addLine(  "singular ||= '%1$s'", singularName);
        buffer.addLine(  "plural ||= '%1$s'", pluralName);
        buffer.addLine(  "writer.write_start(plural)", pluralName);
        buffer.addLine(  "if list.is_a?(%1$s)", rubyNames.getBaseListName().getClassName());
        buffer.addLine(    "href = list.href");
        buffer.addLine(    "writer.write_attribute('href', href) unless href.nil?");
        buffer.addLine(  "end");
        buffer.addLine(  "list.each do |item|");
        buffer.addLine(    "write_one(item, writer, singular)");
        buffer.addLine(  "end");
        buffer.addLine(  "writer.write_end");
        buffer.addLine("end");
        buffer.addLine();

        // End class:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateMembersWrite(StructType type) {
        // Generate the code that writes the members that are represented as XML attributes:
        type.attributes()
            .filter(x -> schemaNames.isRepresentedAsAttribute(x.getName()))
            .sorted()
            .forEach(this::generateMemberWriteAsAttribute);
        type.links()
            .filter(x -> schemaNames.isRepresentedAsAttribute(x.getName()))
            .sorted()
            .forEach(this::generateMemberWriteAsAttribute);

        // Generate the code that writes the members that are represented as inner elements:
        type.attributes()
            .filter(x -> !schemaNames.isRepresentedAsAttribute(x.getName()))
            .sorted()
            .forEach(this::generateMemberWriteAsElement);
        type.links()
            .filter(x -> !schemaNames.isRepresentedAsAttribute(x.getName()))
            .sorted()
            .forEach(this::generateMemberWriteAsElement);
    }

    private void generateMemberWriteAsAttribute(StructMember member) {
        Name name = member.getName();
        Type type = member.getType();
        String property = rubyNames.getMemberStyleName(name);
        String attribute = schemaNames.getSchemaTagName(name);
        if (type instanceof PrimitiveType) {
            generateWritePrimitivePropertyAsAttribute((PrimitiveType) type, attribute, "object." + property);
        }
        else if (type instanceof EnumType) {
            generateWriteEnumPropertyAsAttribute((EnumType) type, attribute, "object." + property);
        }
    }

    private void generateWritePrimitivePropertyAsAttribute(PrimitiveType type, String tag, String value) {
        Model model = type.getModel();
        if (type == model.getStringType()) {
            buffer.addLine("writer.write_attribute('%1$s', %2$s) unless %2$s.nil?", tag, value);
        }
        else if (type == model.getBooleanType() || type == model.getIntegerType() || type == model.getDecimalType()) {
            buffer.addLine("writer.write_attribute('%1$s', %2$s.to_s) unless %2$s.nil?", tag, value);
        }
        else if (type == model.getDateType()) {
            buffer.addLine("writer.write_attribute('%1$s', %2$s.xmlschema) unless %2$s.nil?", tag, value);
        }
    }

    private void generateWriteEnumPropertyAsAttribute(EnumType type, String attribute, String value) {
        buffer.addLine("Writer.write_string(writer, '%1$s', %2$s) unless %2$s.nil?", attribute, value);
    }

    private void generateMemberWriteAsElement(StructMember member) {
        Name name = member.getName();
        Type type = member.getType();
        String property = rubyNames.getMemberStyleName(name);
        String tag = schemaNames.getSchemaTagName(name);
        if (type instanceof PrimitiveType) {
            generateWritePrimitivePropertyAsElement((PrimitiveType) type, tag, "object." + property);
        }
        else if (type instanceof EnumType) {
            generateWriteEnumPropertyAsElement((EnumType) type, tag, "object." + property);
        }
        else if (type instanceof StructType) {
            generateWriteStructPropertyAsElement(member);
        }
        else if (type instanceof ListType) {
            generateWriteListPropertyAsElement(member);
        }
    }

    private void generateWritePrimitivePropertyAsElement(PrimitiveType type, String tag, String value) {
        Model model = type.getModel();
        if (type == model.getStringType()) {
            buffer.addLine("Writer.write_string(writer, '%1$s', %2$s) unless %2$s.nil?", tag, value);
        }
        else if (type == model.getBooleanType()) {
            buffer.addLine("Writer.write_boolean(writer, '%1$s', %2$s) unless %2$s.nil?", tag, value);
        }
        else if (type == model.getIntegerType()) {
            buffer.addLine("Writer.write_integer(writer, '%1$s', %2$s) unless %2$s.nil?", tag, value);
        }
        else if (type == model.getDecimalType()) {
            buffer.addLine("Writer.write_decimal(writer, '%1$s', %2$s) unless %2$s.nil?", tag, value);
        }
        else if (type == model.getDateType()) {
            buffer.addLine("Writer.write_date(writer, '%1$s', %2$s) unless %2$s.nil?", tag, value);
        }
    }

    private void generateWriteEnumPropertyAsElement(EnumType type, String tag, String value) {
        buffer.addLine("Writer.write_string(writer, '%1$s', %2$s) unless %2$s.nil?", tag, value);
    }

    private void generateWriteStructPropertyAsElement(StructMember member) {
        Name name = member.getName();
        Type type = member.getType();
        String property = rubyNames.getMemberStyleName(name);
        String tag = schemaNames.getSchemaTagName(name);
        RubyName writerName = rubyNames.getWriterName(type);
        buffer.addLine(
            "%1$s.write_one(object.%2$s, writer, '%3$s') unless object.%2$s.nil?",
            writerName.getClassName(),
            property,
            tag
        );
    }

    private void generateWriteListPropertyAsElement(StructMember member) {
        Name name = member.getName();
        Type type = member.getType();
        ListType listType = (ListType) type;
        Type elementType = listType.getElementType();
        String property = rubyNames.getMemberStyleName(name);
        String pluralTag = schemaNames.getSchemaTagName(name);
        String singularTag = schemaNames.getSchemaTagName(names.getSingular(name));
        if (elementType instanceof PrimitiveType || elementType instanceof EnumType) {
            buffer.addLine("if not object.%1$s.nil? and not object.%1$s.empty? then", property);
            buffer.addLine(  "writer.write_start('%1$s')", pluralTag);
            buffer.addLine(  "object.%1$s.each do |item|", property);
            if (elementType instanceof PrimitiveType) {
                generateWritePrimitivePropertyAsElement((PrimitiveType) elementType, singularTag, "item");
            }
            else if (elementType instanceof EnumType) {
                generateWriteEnumPropertyAsElement((EnumType) elementType, singularTag, "item");
            }
            buffer.addLine(  "end");
            buffer.addLine(  "writer.end_element");
            buffer.addLine("end");
        }
        else if (elementType instanceof StructType) {
            RubyName elementWriterName = rubyNames.getWriterName(elementType);
            buffer.addLine(
                "%1$s.write_many(object.%2$s, writer, '%3$s', '%4$s') unless object.%2$s.nil?",
                elementWriterName.getClassName(),
                property,
                singularTag,
                pluralTag
            );
        }
    }
}

