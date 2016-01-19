/*
Copyright (c) 2015 Red Hat, Inc.

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
import org.ovirt.api.metamodel.concepts.Link;
import org.ovirt.api.metamodel.concepts.ListType;
import org.ovirt.api.metamodel.concepts.Model;
import org.ovirt.api.metamodel.concepts.Name;
import org.ovirt.api.metamodel.concepts.PrimitiveType;
import org.ovirt.api.metamodel.concepts.StructMember;
import org.ovirt.api.metamodel.concepts.StructType;
import org.ovirt.api.metamodel.concepts.Type;
import org.ovirt.api.metamodel.tool.SchemaNames;

/**
 * This class is responsible for generating the classes that create instances of model types from XML documents.
 */
public class ReadersGenerator implements RubyGenerator {
    // The directory were the output will be generated:
    protected File out;

    // Reference to the objects used to generate the code:
    @Inject private SchemaNames schemaNames;
    @Inject private RubyNames rubyNames;

    // The buffer used to generate the Ruby code:
    private RubyBuffer buffer;

    public void setOut(File newOut) {
        out = newOut;
    }

    public void generate(Model model) {
        // Generate a file for each reader, and then one large file containing forward declarations of all the readers
        // and "load" statements to load them:
        generateReaderFiles(model);
        generateReadersFile(model);
    }

    private void generateReaderFiles(Model model) {
        model.types()
            .filter(x -> x instanceof StructType)
            .forEach(this::generateReaderFile);
    }

    private void generateReaderFile(Type type) {
        // Get the name of the class:
        RubyName readerName = rubyNames.getReaderName(type);

        // Generate the source:
        buffer = new RubyBuffer();
        buffer.setFileName(readerName.getFileName());
        generateReader(type);
        try {
            buffer.write(out);
        }
        catch (IOException exception) {
            throw new IllegalStateException("Error writing reader \"" + readerName + "\"", exception);
        }
    }

    private void generateReader(Type type) {
        // Begin module:
        RubyName readerName = rubyNames.getReaderName(type);
        buffer.beginModule(readerName.getModuleName());
        buffer.addLine();

        // Check the kind of type:
        if (type instanceof StructType) {
            generateStruct((StructType) type);
        }

        // End module:
        buffer.endModule(readerName.getModuleName());
    }

    private void generateStruct(StructType type) {
        // Begin class:
        generateClassDeclaration(type);
        buffer.addLine();

        // Generate the methods:
        generateMethods(type);

        // End class:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateMethods(StructType type) {
        RubyName typeName = rubyNames.getTypeName(type);

        // Generate the method that reads one instance:
        buffer.addLine("def self.read_one(reader, connection = nil)");
        buffer.addLine(  "# Do nothing if there aren't more tags:");
        buffer.addLine(  "return nil unless reader.forward");
        buffer.addLine();
        buffer.addLine(  "# Create the object:");
        buffer.addLine(  "object = %s.new", typeName.getClassName());
        buffer.addLine(  "object.connection = connection");
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
        buffer.addLine("def self.read_many(reader, connection = nil)");
        buffer.addLine(  "# Do nothing if there aren't more tags:");
        buffer.addLine(  "list = %1$s.new", rubyNames.getBaseListName().getClassName());
        buffer.addLine(  "list.connection = connection");
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
        buffer.addLine(    "list << read_one(reader, connection)");
        buffer.addLine(  "end");
        buffer.addLine();
        buffer.addLine(  "# Discard the end tag:");
        buffer.addLine(  "reader.read");
        buffer.addLine();
        buffer.addLine(  "return list");
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
        long count = type.attributes().count() + type.links().count();
        if (count > 0) {
            buffer.addLine("while reader.forward do");
            buffer.addLine(  "case reader.node_name");
            type.attributes().sorted().forEach(this::generateElementRead);
            type.links().sorted().forEach(this::generateElementRead);
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
            buffer.addLine("%1$s = reader.read_string", variable);
            buffer.addLine("reader.next_element");
        }
        else if (type == model.getBooleanType()) {
            buffer.addLine("%1$s = reader.read_boolean", variable);
        }
        else if (type == model.getIntegerType()) {
            buffer.addLine("%1$s = reader.read_integer", variable);
        }
        else if (type == model.getDecimalType()) {
            buffer.addLine("%1$s = reader.read_decimal", variable);
        }
        else if (type == model.getDateType()) {
            buffer.addLine("%1$s = reader.read_date", variable);
        }
        else {
            buffer.addLine("reader.next_element");
        }
    }

    private void generateReadEnum(StructMember member, String variable) {
        buffer.addLine("%1$s = reader.read_string", variable);
        buffer.addLine("reader.next_element");
    }

    private void generateReadStruct(StructMember member, String variable) {
        RubyName readerName = rubyNames.getReaderName(member.getType());
        buffer.addLine("%1$s = %2$s.read_one(reader, connection)", variable, readerName.getClassName());
        buffer.addLine("%1$s.is_link = %2$s", variable, member instanceof Link);
    }

    private void generateReadList(StructMember member, String variable) {
        ListType type = (ListType) member.getType();
        Type elementType = type.getElementType();
        if (elementType instanceof PrimitiveType) {
            buffer.addLine("reader.next_element");
        }
        else if (elementType instanceof StructType) {
            RubyName readerName = rubyNames.getReaderName(elementType);
            buffer.addLine("%1$s = %2$s.read_many(reader, connection)", variable, readerName.getClassName());
            buffer.addLine("%1$s.is_link = %2$s", variable, member instanceof Link);
        }
        else {
            buffer.addLine("reader.next_element");
        }
    }

    private void generateReadersFile(Model model) {
        // Calculate the file name:
        String fileName = rubyNames.getModulePath() + "/readers";
        buffer = new RubyBuffer();
        buffer.setFileName(fileName);

        // Begin module:
        buffer.addLine("##");
        buffer.addLine("# These forward declarations are required in order to avoid circular dependencies.");
        buffer.addLine("#");
        buffer.beginModule(rubyNames.getModuleName());
        buffer.addLine();

        // Generate the forward declarations using the order calculated in the previous step:
        buffer.addLine("class %1$s # :nodoc:", rubyNames.getBaseReaderName().getClassName());
        buffer.addLine("end");
        buffer.addLine();
        model.types()
            .filter(StructType.class::isInstance)
            .map(StructType.class::cast)
            .sorted()
            .forEach(x -> {
                generateClassDeclaration(x);
                buffer.addLine("end");
                buffer.addLine();
            });

        // End module:
        buffer.endModule(rubyNames.getModuleName());
        buffer.addLine();

        // Generate the load statements:
        buffer.addLine("##");
        buffer.addLine("# Load all the readers.");
        buffer.addLine("#");
        buffer.addLine("load '%1$s.rb'", rubyNames.getBaseReaderName().getFileName());
        buffer.addLine("load '%1$s.rb'", rubyNames.getFaultReaderName().getFileName());
        model.types()
            .filter(x -> x instanceof StructType)
            .sorted()
            .map(rubyNames::getReaderName)
            .forEach(this::generateLoadStatement);

        // Write the file:
        try {
            buffer.write(out);
        }
        catch (IOException exception) {
            throw new IllegalStateException("Error writing types file \"" + fileName + "\"", exception);
        }
    }

    private void generateClassDeclaration(StructType type) {
        RubyName readerName = rubyNames.getReaderName(type);
        RubyName baseName = rubyNames.getBaseReaderName();
        buffer.addLine("class %1$s < %2$s # :nodoc:", readerName.getClassName(), baseName.getClassName());
    }

    private void generateLoadStatement(RubyName name) {
        buffer.addLine("load '%1$s.rb'", name.getFileName());
    }
}

