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

import static java.util.stream.Collectors.joining;
import static java.util.stream.Collectors.toList;

import java.io.File;
import java.io.IOException;
import java.util.List;
import javax.enterprise.inject.spi.CDI;
import javax.inject.Inject;

import org.ovirt.api.metamodel.concepts.EnumType;
import org.ovirt.api.metamodel.concepts.Link;
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
 * This class is responsible for generating the classes that create instances of model types from XML documents.
 */
public class ReadersGenerator implements RubyGenerator {
    // The directory were the output will be generated:
    protected File out;

    // Reference to the objects used to generate the code:
    @Inject private Names names;
    @Inject private SchemaNames schemaNames;
    @Inject private RubyNames rubyNames;

    // The buffer used to generate the Ruby code:
    @Inject private RubyBuffer buffer;

    public void setOut(File newOut) {
        out = newOut;
    }

    public void generate(Model model) {
        // Calculate the file name:
        String fileName = rubyNames.getModulePath() + "/readers";
        buffer = CDI.current().select(RubyBuffer.class).get();
        buffer.setFileName(fileName);

        // Generate the source:
        generateSource(model);

        // Write the file:
        try {
            buffer.write(out);
        }
        catch (IOException exception) {
            throw new IllegalStateException("Error writing readers file \"" + fileName + "\"", exception);
        }
    }

    private void generateSource(Model model) {
        // Begin module:
        String moduleName = rubyNames.getModuleName();
        buffer.beginModule(moduleName);
        buffer.addLine();

        // Generate a reader for each struct type:
        model.types()
            .filter(StructType.class::isInstance)
            .map(StructType.class::cast)
            .sorted()
            .forEach(this::generateReader);

        // Generate code to register the readers:
        model.types()
            .filter(StructType.class::isInstance)
            .map(StructType.class::cast)
            .sorted()
            .forEach(type -> {
                Name typeName = type.getName();
                String singularTag = schemaNames.getSchemaTagName(typeName);
                String pluralTag = schemaNames.getSchemaTagName(names.getPlural(typeName));
                String className = rubyNames.getReaderName(type).getClassName();
                buffer.addLine("Reader.register('%1$s', %2$s.method(:read_one))", singularTag, className);
                buffer.addLine("Reader.register('%1$s', %2$s.method(:read_many))", pluralTag, className);
            });

        // End module:
        buffer.endModule(moduleName);
        buffer.addLine();
    }

    private void generateReader(StructType type) {
        // Begin class:
        RubyName typeName = rubyNames.getTypeName(type);
        RubyName readerName = rubyNames.getReaderName(type);
        RubyName baseName = rubyNames.getBaseReaderName();
        buffer.addLine("class %1$s < %2$s # :nodoc:", readerName.getClassName(), baseName.getClassName());
        buffer.addLine();

        // Generate the method that reads one instance:
        buffer.addLine("def self.read_one(reader)");
        buffer.addLine(  "# Do nothing if there aren't more tags:");
        buffer.addLine(  "return nil unless reader.forward");
        buffer.addLine();
        buffer.addLine(  "# Create the object:");
        buffer.addLine(  "object = %s.new", typeName.getClassName());
        buffer.addLine();
        buffer.addLine(  "# Process the attributes:");
        buffer.addLine(  "object.href = reader.get_attribute('href')");
        generateAttributesRead(type);
        buffer.addLine();
        buffer.addLine(  "# Discard the start tag:");
        buffer.addLine(  "empty = reader.empty_element?");
        buffer.addLine(  "reader.read");
        buffer.addLine(  "return object if empty");
        buffer.addLine();
        buffer.addLine(  "# Process the inner elements:");
        generateElementsRead(type);
        buffer.addLine();
        buffer.addLine(  "# Discard the end tag:");
        buffer.addLine(  "reader.read");
        buffer.addLine();
        buffer.addLine(  "return object");
        buffer.addLine("end");
        buffer.addLine();
        buffer.addLine();

        // Generate the method that reads many instances:
        buffer.addLine("def self.read_many(reader)");
        buffer.addLine(  "# Do nothing if there aren't more tags:");
        buffer.addLine(  "list = %1$s.new", rubyNames.getBaseListName().getClassName());
        buffer.addLine(  "return list unless reader.forward");
        buffer.addLine();
        buffer.addLine(  "# Process the attributes:");
        buffer.addLine(  "list.href = reader.get_attribute('href')");
        buffer.addLine();
        buffer.addLine(  "# Discard the start tag:");
        buffer.addLine(  "empty = reader.empty_element?");
        buffer.addLine(  "reader.read");
        buffer.addLine(  "return list if empty");
        buffer.addLine();
        buffer.addLine(  "# Process the inner elements:");
        buffer.addLine(  "while reader.forward do");
        buffer.addLine(    "list << read_one(reader)");
        buffer.addLine(  "end");
        buffer.addLine();
        buffer.addLine(  "# Discard the end tag:");
        buffer.addLine(  "reader.read");
        buffer.addLine();
        buffer.addLine(  "return list");
        buffer.addLine("end");
        buffer.addLine();

        // Generate the method that reads links to lists:
        List<Link> listLinks = type.links()
            .filter(link -> link.getType() instanceof ListType)
            .sorted()
            .collect(toList());
        if (!listLinks.isEmpty()) {
            buffer.addLine("def self.read_link(reader, object)");
            buffer.addLine(  "# Process the attributes:");
            buffer.addLine(  "rel = reader.get_attribute('rel')");
            buffer.addLine(  "href = reader.get_attribute('href')");
            buffer.addLine(  "if rel && href");
            buffer.addLine(    "list = %1$s.new", rubyNames.getBaseListName().getClassName());
            buffer.addLine(    "list.href = href");
            buffer.addLine(    "case rel");
            listLinks.forEach(link -> {
                Name name = link.getName();
                String property = rubyNames.getMemberStyleName(name);
                String rel = name.words().map(String::toLowerCase).collect(joining());
                buffer.addLine("when '%1$s'", rel);
                buffer.addLine(  "object.%1$s = list", property);
            });
            buffer.addLine(    "end");
            buffer.addLine(  "end");
            buffer.addLine();
            buffer.addLine(  "# Discard the rest of the element:");
            buffer.addLine(  "reader.next_element");
            buffer.addLine("end");
            buffer.addLine();
        }

        // End class:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateAttributesRead(StructType type) {
        type.attributes().sorted().forEach(this::generateAttributeRead);
        type.links().sorted().forEach(this::generateAttributeRead);
    }

    private void generateAttributeRead(StructMember member) {
        Name name = member.getName();
        Type type = member.getType();
        if (type instanceof PrimitiveType || type instanceof EnumType) {
            String property = rubyNames.getMemberStyleName(name);
            String tag = schemaNames.getSchemaTagName(name);
            buffer.addLine("value = reader.get_attribute('%s')", tag);
            buffer.addLine("object.%1$s = value if not value.nil?", property);
        }
    }

    private void generateElementsRead(StructType type) {
        long attributesCount = type.attributes().count();
        long linksCount = type.links().count();
        long listLinksCount = type.links()
            .filter(link -> link.getType() instanceof ListType)
            .count();
        long membersCount = attributesCount + linksCount;
        if (membersCount > 0) {
            buffer.addLine("while reader.forward do");
            buffer.addLine(  "case reader.node_name");
            type.attributes().sorted().forEach(this::generateElementRead);
            type.links().sorted().forEach(this::generateElementRead);
            if (listLinksCount > 0) {
                buffer.addLine("when 'link'");
                buffer.addLine(  "read_link(reader, object)");
            }
            buffer.addLine(  "else");
            buffer.addLine(    "reader.next_element");
            buffer.addLine(  "end");
            buffer.addLine("end");
        }
        else {
            buffer.addLine("reader.next_element");
        }
    }

    private void generateElementRead(StructMember member) {
        Name name = member.getName();
        Type type = member.getType();
        String property = rubyNames.getMemberStyleName(name);
        String tag = schemaNames.getSchemaTagName(name);
        String variable = String.format("object.%1$s", property);
        buffer.addLine("when '%1$s'", tag);
        if (type instanceof PrimitiveType) {
            generateReadPrimitive(member, variable);
        }
        else if (type instanceof EnumType) {
            generateReadEnum(member, variable);
        }
        else if (type instanceof StructType) {
            generateReadStruct(member, variable);
        }
        else if (type instanceof ListType) {
            generateReadList(member, variable);
        }
        else {
            buffer.addLine("reader.next_element");
        }
    }

    private void generateReadPrimitive(StructMember member, String variable) {
        Type type = member.getType();
        Model model = type.getModel();
        if (type == model.getStringType()) {
            buffer.addLine("%1$s = Reader.read_string(reader)", variable);
        }
        else if (type == model.getBooleanType()) {
            buffer.addLine("%1$s = Reader.read_boolean(reader)", variable);
        }
        else if (type == model.getIntegerType()) {
            buffer.addLine("%1$s = Reader.read_integer(reader)", variable);
        }
        else if (type == model.getDecimalType()) {
            buffer.addLine("%1$s = Reader.read_decimal(reader)", variable);
        }
        else if (type == model.getDateType()) {
            buffer.addLine("%1$s = Reader.read_date(reader)", variable);
        }
        else {
            buffer.addLine("reader.next_element");
        }
    }

    private void generateReadEnum(StructMember member, String variable) {
        buffer.addLine("%1$s = Reader.read_string(reader)", variable);
    }

    private void generateReadStruct(StructMember member, String variable) {
        RubyName readerName = rubyNames.getReaderName(member.getType());
        buffer.addLine("%1$s = %2$s.read_one(reader)", variable, readerName.getClassName());
    }

    private void generateReadList(StructMember member, String variable) {
        ListType type = (ListType) member.getType();
        Type elementType = type.getElementType();
        if (elementType instanceof PrimitiveType) {
            generateReadPrimitives((PrimitiveType) elementType, variable);
        }
        else if (elementType instanceof EnumType) {
            generateReadEnum((EnumType) elementType, variable);
        }
        else if (elementType instanceof StructType) {
            RubyName readerName = rubyNames.getReaderName(elementType);
            buffer.addLine("%1$s = %2$s.read_many(reader)", variable, readerName.getClassName());
        }
        else {
            buffer.addLine("reader.next_element");
        }
    }

    private void generateReadPrimitives(PrimitiveType type, String variable) {
        Model model = type.getModel();
        if (type == model.getStringType()) {
            buffer.addLine("%1$s = Reader.read_strings(reader)", variable);
        }
        else if (type == model.getBooleanType()) {
            buffer.addLine("%1$s = Reader.read_booleans(reader)", variable);
        }
        else if (type == model.getIntegerType()) {
            buffer.addLine("%1$s = Reader.read_integers(reader)", variable);
        }
        else if (type == model.getDecimalType()) {
            buffer.addLine("%1$s = Reader.read_decimals(reader)", variable);
        }
        else if (type == model.getDateType()) {
            buffer.addLine("%1$s = Reader.read_dates(reader)", variable);
        }
        else {
            buffer.addLine("reader.next_element");
        }
    }

    private void generateReadEnum(EnumType type, String variable) {
        buffer.addLine("%1$s = Reader.read_strings(reader)", variable);
    }
}

