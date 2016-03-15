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
import static java.util.stream.Collectors.toCollection;

import java.io.File;
import java.io.IOException;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Optional;
import javax.inject.Inject;

import org.ovirt.api.metamodel.concepts.EnumType;
import org.ovirt.api.metamodel.concepts.ListType;
import org.ovirt.api.metamodel.concepts.Locator;
import org.ovirt.api.metamodel.concepts.Method;
import org.ovirt.api.metamodel.concepts.Model;
import org.ovirt.api.metamodel.concepts.Name;
import org.ovirt.api.metamodel.concepts.NameParser;
import org.ovirt.api.metamodel.concepts.Parameter;
import org.ovirt.api.metamodel.concepts.PrimitiveType;
import org.ovirt.api.metamodel.concepts.Service;
import org.ovirt.api.metamodel.concepts.StructType;
import org.ovirt.api.metamodel.concepts.Type;
import org.ovirt.api.metamodel.tool.SchemaNames;

/**
 * This class is responsible for generating the classes that represent the services of the model.
 */
public class ServicesGenerator implements RubyGenerator {
    // Well known method names:
    private static final Name ADD = NameParser.parseUsingCase("Add");
    private static final Name GET = NameParser.parseUsingCase("Get");
    private static final Name LIST = NameParser.parseUsingCase("List");
    private static final Name REMOVE = NameParser.parseUsingCase("Remove");
    private static final Name UPDATE = NameParser.parseUsingCase("Update");

    // The directory were the output will be generated:
    protected File out;

    // Reference to the objects used to generate the code:
    @Inject private RubyNames rubyNames;
    @Inject private SchemaNames schemaNames;
    @Inject private YardDoc yardDoc;

    // The buffer used to generate the Ruby code:
    private RubyBuffer buffer;

    /**
     * Set the directory were the output will be generated.
     */
    public void setOut(File newOut) {
        out = newOut;
    }

    public void generate(Model model) {
        // Calculate the file name:
        String fileName = rubyNames.getModulePath() + "/services";
        buffer = new RubyBuffer();
        buffer.setFileName(fileName);

        // Generate the source:
        generateSource(model);

        // Write the file:
        try {
            buffer.write(out);
        }
        catch (IOException exception) {
            throw new IllegalStateException("Error writing services file \"" + fileName + "\"", exception);
        }
    }

    private void generateSource(Model model) {
        // Begin module:
        buffer.addLine("##");
        buffer.addLine("# These forward declarations are required in order to avoid circular dependencies.");
        buffer.addLine("#");
        String moduleName = rubyNames.getModuleName();
        buffer.beginModule(moduleName);
        buffer.addLine();

        // The declarations of the services need to appear in inheritance order, otherwise some symbols won't be
        // defined and that will produce errors. To order them correctly we need first to sort them by name, and
        // then sort again so that bases are before extensions.
        Deque<Service> pending = model.services()
            .sorted()
            .collect(toCollection(ArrayDeque::new));
        Deque<Service> sorted = new ArrayDeque<>(pending.size());
        while (!pending.isEmpty()) {
            Service current = pending.removeFirst();
            Service base = current.getBase();
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
        sorted.forEach(this::generateService);

        // End module:
        buffer.endModule(moduleName);
        buffer.addLine();

    }

    private void generateService(Service service) {
        // Begin class:
        generateClassDeclaration(service);
        buffer.addLine();

        // Generate the constructor:
        buffer.addLine("##");
        buffer.addLine("# Creates a new implementation of the service.");
        buffer.addLine("#");
        buffer.addLine("# @param connection [Connection] The connection to be used by this service.");
        buffer.addLine("# @param path [String] The relative path of this service, for example `vms/123/disks`.");
        buffer.addLine("#");
        buffer.addLine("# @api private");
        buffer.addLine("#");
        buffer.addLine("def initialize(connection, path)");
        buffer.addLine(  "@connection = connection");
        buffer.addLine(  "@path = path");
        buffer.addLine("end");
        buffer.addLine();

        // Generate the methods and locators:
        service.methods().sorted().forEach(this::generateMethod);
        service.locators().sorted().forEach(this::generateLocator);
        generatePathLocator(service);

        // Generate other methods that don't correspond to model methods or locators:
        generateToS(service);

        // End class:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateMethod(Method method) {
        Name name = method.getName();
        if (ADD.equals(name)) {
            generateAddHttpPost(method);
        }
        else if (GET.equals(name) || LIST.equals(name)) {
            generateHttpGet(method);
        }
        else if (REMOVE.equals(name)) {
            generateHttpDelete(method);
        }
        else if (UPDATE.equals(name)) {
            generateHttpPut(method);
        }
        else {
            generateActionHttpPost(method);
        }
    }

    private void generateAddHttpPost(Method method) {
        // Get the main parameter:
        Parameter parameter = method.parameters()
            .filter(x -> x.isIn() && x.isOut())
            .findFirst()
            .orElse(null);

        // Begin method:
        Name methodName = method.getName();
        Type parameterType = parameter.getType();
        Name parameterName = parameter.getName();
        String arg = rubyNames.getMemberStyleName(parameterName);
        buffer.addLine("##");
        buffer.addLine("# Adds a new `%1$s`.", arg);
        buffer.addLine("#");
        buffer.addLine("# @param %1$s [%2$s]", arg, yardDoc.getType(parameterType));
        buffer.addLine("# @return [%1$s]", yardDoc.getType(parameterType));
        buffer.addLine("#");
        buffer.addLine("def %1$s(%2$s, opts = {})", rubyNames.getMemberStyleName(methodName), arg);

        // Body:
        String tag = schemaNames.getSchemaTagName(parameterName);
        generateConvertLiteral(parameterType, arg);
        buffer.addLine("request = Request.new(:method => :POST, :path => @path)");
        generateWriteRequestBody(parameter, arg);
        buffer.addLine("response = @connection.send(request)");
        buffer.addLine("case response.code");
        buffer.addLine("when 201, 202");
        generateReturnResponseBody(parameter);
        buffer.addLine("else");
        buffer.addLine(  "check_fault(response)");
        buffer.addLine("end");

        // End method:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateActionHttpPost(Method method) {
        // Begin method:
        Name methodName = method.getName();
        String actionName = rubyNames.getMemberStyleName(methodName);
        buffer.addLine("##");
        buffer.addLine("# Executes the `%1$s` method.", actionName);
        buffer.addLine("#");
        buffer.addLine("def %1$s(opts = {})", actionName);

        // Generate the method:
        buffer.addLine("writer = XmlWriter.new(nil, true)");
        buffer.addLine("writer.write_start('action')");
        method.parameters()
            .filter(Parameter::isIn)
            .sorted()
            .forEach(this::generateWriteActionParameter);
        buffer.addLine("writer.write_end");
        buffer.addLine("body = writer.string");
        buffer.addLine("writer.close");
        buffer.addLine("request = Request.new({");
        buffer.addLine(  ":method => :POST,");
        buffer.addLine(  ":path => \"#{@path}/%1$s\",", getPath(methodName));
        buffer.addLine(  ":body => body,");
        buffer.addLine("})");
        buffer.addLine("response = @connection.send(request)");
        buffer.addLine("case response.code");
        buffer.addLine("when 200");
        buffer.addLine(  "check_action(response)");
        buffer.addLine("else");
        buffer.addLine(  "check_fault(response)");
        buffer.addLine("end");

        // End method:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateWriteActionParameter(Parameter parameter) {
        Type type = parameter.getType();
        Name name = parameter.getName();
        String symbol = rubyNames.getMemberStyleName(name);
        String tag = schemaNames.getSchemaTagName(name);
        buffer.addLine("value = opts[:%1$s]", symbol);
        if (type instanceof PrimitiveType) {
            Model model = type.getModel();
            if (type == model.getStringType()) {
                buffer.addLine("writer.write_string('%1$s', value) unless value.nil?", tag);
            }
            else if (type == model.getBooleanType()) {
                buffer.addLine("writer.write_boolean('%1$s', value) unless value.nil?", tag);
            }
            else if (type == model.getIntegerType()) {
                buffer.addLine("writer.write_integer('%1$s', value) unless value.nil?", tag);
            }
            else if (type == model.getDecimalType()) {
                buffer.addLine("writer.write_decimal('%1$s', value) unless value.nil?", tag);
            }
            else if (type == model.getDateType()) {
                buffer.addLine("writer.write_date('%1$s', value) unless value.nil?", tag);
            }
        }
        else if (type instanceof EnumType) {
            buffer.addLine("writer.write_string('%1$s', value) unless value.nil?", tag);
        }
        else if (type instanceof StructType) {
            RubyName writer = rubyNames.getWriterName(type);
            buffer.addLine("%1$s.write_one(value, writer) unless value.nil?", writer.getClassName());
        }
        else if (type instanceof ListType) {
            ListType listType = (ListType) type;
            Type elementType = listType.getElementType();
            RubyName writer = rubyNames.getWriterName(elementType);
            buffer.addLine("%1$s.write_many(value, writer) unless value.nil?", writer.getClassName());
        }
    }

    private void generateHttpGet(Method method) {
        // Get the output parameter:
        Parameter parameter = method.parameters()
            .filter(Parameter::isOut)
            .findFirst()
            .orElse(null);

        // Begin method:
        Name methodName = method.getName();
        buffer.addLine("def %1$s(opts = {})", rubyNames.getMemberStyleName(methodName));

        // Generate the input parameters:
        buffer.addLine("query = {}");
        method.parameters()
            .filter(Parameter::isIn)
            .sorted()
            .forEach(this::generateUrlParameter);

        // Body:
        buffer.addLine("request = Request.new(:method => :GET, :path => @path, :query => query)");
        buffer.addLine("response = @connection.send(request)");
        buffer.addLine("case response.code");
        buffer.addLine("when 200");
        generateReturnResponseBody(parameter);
        buffer.addLine("else");
        buffer.addLine(  "check_fault(response)");
        buffer.addLine("end");

        // End method:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateHttpPut(Method method) {
        // Get the main parameter:
        Parameter parameter = method.parameters()
            .filter(x -> x.isIn() && x.isOut())
            .findFirst()
            .orElse(null);

        // Begin method:
        Name methodName = method.getName();
        Name parameterName = parameter.getName();
        Type parameterType = parameter.getType();
        String arg = rubyNames.getMemberStyleName(parameterName);
        buffer.addLine("def %1$s(%2$s)", rubyNames.getMemberStyleName(methodName), arg);

        // Body:
        generateConvertLiteral(parameterType, arg);
        buffer.addLine("request = Request.new(:method => :PUT, :path => @path)");
        generateWriteRequestBody(parameter, arg);
        buffer.addLine("response = @connection.send(request)");
        buffer.addLine("case response.code");
        buffer.addLine("when 200");
        generateReturnResponseBody(parameter);
        buffer.addLine(  "return result");
        buffer.addLine("else");
        buffer.addLine(  "check_fault(response)");
        buffer.addLine("end");

        // End method:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateConvertLiteral(Type type, String variable) {
        if (type instanceof StructType) {
            buffer.addLine("if %1$s.is_a?(Hash)", variable);
            buffer.addLine(  "%1$s = %2$s.new(%1$s)", variable, rubyNames.getTypeName(type));
            buffer.addLine("end");
        }
        else if (type instanceof ListType) {
            ListType listType = (ListType) type;
            Type elementType = listType.getElementType();
            buffer.addLine("if %1$s.is_a?(Array)", variable);
            buffer.addLine(  "%1$s = List.new(%1$s)", variable);
            buffer.addLine(  "%1$s.each_with_index do |value, index|", variable);
            buffer.addLine(    "if value.is_a?(Hash)");
            buffer.addLine(      "%1$s[index] = %2$s.new(value)", variable, rubyNames.getTypeName(elementType));
            buffer.addLine(    "end");
            buffer.addLine(  "end");
            buffer.addLine("end");
        }
    }

    private void generateWriteRequestBody(Parameter parameter, String variable) {
        Name name = parameter.getName();
        Type type = parameter.getType();
        String tag = schemaNames.getSchemaTagName(name);
        buffer.addLine("begin");
        buffer.addLine(  "writer = XmlWriter.new(nil, true)");
        if (type instanceof StructType) {
            RubyName writer = rubyNames.getWriterName(type);
            buffer.addLine("%1$s.write_one(%2$s, writer, '%3$s')", writer.getClassName(), variable, tag);
        }
        else if (type instanceof ListType) {
            ListType listType = (ListType) type;
            Type elementType = listType.getElementType();
            RubyName writer = rubyNames.getWriterName(elementType);
            buffer.addLine("%1$s.write_many(%2$s, writer, '%3$s')", writer.getClassName(), variable, tag);
        }
        buffer.addLine(  "request.body = writer.string");
        buffer.addLine("ensure");
        buffer.addLine(  "writer.close");
        buffer.addLine("end");
    }

    private void generateReturnResponseBody(Parameter parameter) {
        Type type = parameter.getType();
        buffer.addLine("begin");
        buffer.addLine(  "reader = XmlReader.new(response.body)");
        if (type instanceof StructType) {
            RubyName reader = rubyNames.getReaderName(type);
            buffer.addLine("return %1$s.read_one(reader)", reader.getClassName());
        }
        else if (type instanceof ListType) {
            ListType listType = (ListType) type;
            Type elementType = listType.getElementType();
            RubyName reader = rubyNames.getReaderName(elementType);
            buffer.addLine("return %1$s.read_many(reader)", reader.getClassName());
        }
        buffer.addLine("ensure");
        buffer.addLine(  "reader.close");
        buffer.addLine("end");
    }

    private void generateHttpDelete(Method method) {
        // Begin method:
        Name name = method.getName();
        buffer.addLine("def %1$s(opts = {})", rubyNames.getMemberStyleName(name));

        // Generate the input parameters:
        buffer.addLine("query = {}");
        method.parameters()
            .filter(Parameter::isIn)
            .sorted()
            .forEach(this::generateUrlParameter);

        // Generate the method:
        buffer.addLine(  "request = Request.new(:method => :DELETE, :path => @path, :query => query)");
        buffer.addLine(  "response = @connection.send(request)");
        buffer.addLine(  "unless response.code == 200");
        buffer.addLine(    "check_fault(response)");
        buffer.addLine(  "end");
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateUrlParameter(Parameter parameter) {
        Type type = parameter.getType();
        Name name = parameter.getName();
        String symbol = rubyNames.getMemberStyleName(name);
        String tag = schemaNames.getSchemaTagName(name);
        buffer.addLine("value = opts[:%1$s]", symbol);
        buffer.addLine("unless value.nil?");
        if (type instanceof PrimitiveType) {
            Model model = type.getModel();
            if (type == model.getBooleanType()) {
                buffer.addLine("value = Writer.render_boolean(value)", tag);
            }
            else if (type == model.getIntegerType()) {
                buffer.addLine("value = Writer.render_integer(value)", tag);
            }
            else if (type == model.getDecimalType()) {
                buffer.addLine("value = Writer.render_decimal(value)", tag);
            }
            else if (type == model.getDateType()) {
                buffer.addLine("value = Writer.render_date(value)", tag);
            }
        }
        buffer.addLine(  "query['%1$s'] = value", tag);
        buffer.addLine("end");
    }

    private void generateToS(Service service) {
        RubyName serviceName = rubyNames.getServiceName(service);
        buffer.addLine("##");
        buffer.addLine("# Returns an string representation of this service.");
        buffer.addLine("#");
        buffer.addLine("# @return [String]");
        buffer.addLine("#");
        buffer.addLine("def to_s");
        buffer.addLine(  "return \"#<#{%1$s}:#{@path}>\"", serviceName.getClassName());
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateLocator(Locator locator) {
        Parameter parameter = locator.getParameters().stream().findFirst().orElse(null);
        if (parameter != null) {
            generateLocatorWithParameters(locator);
        }
        else {
            generateLocatorWithoutParameters(locator);
        }
    }

    private void generateLocatorWithParameters(Locator locator) {
        Parameter parameter = locator.parameters().findFirst().get();
        String methodName = rubyNames.getMemberStyleName(locator.getName());
        String argName = rubyNames.getMemberStyleName(parameter.getName());
        RubyName serviceName = rubyNames.getServiceName(locator.getService());
        buffer.addLine("##");
        buffer.addLine("# Locates the `%1$s` service.", methodName);
        buffer.addLine("#");
        buffer.addLine("# @param %1$s [String] The identifier of the `%2$s`.", argName, methodName);
        buffer.addLine("# @return [%1$s] A reference to the `%2$s` service.", serviceName.getClassName(), methodName);
        buffer.addLine("#");
        buffer.addLine("def %1$s_service(%2$s)", methodName, argName);
        buffer.addLine(  "return %1$s.new(@connection, \"#{@path}/#{%2$s}\")", serviceName.getClassName(), argName);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateLocatorWithoutParameters(Locator locator) {
        String methodName = rubyNames.getMemberStyleName(locator.getName());
        String urlSegment = getPath(locator.getName());
        RubyName serviceName = rubyNames.getServiceName(locator.getService());
        buffer.addLine("##");
        buffer.addLine("# Locates the `%1$s` service.", methodName);
        buffer.addLine("#");
        buffer.addLine("# @return [%1$s] A reference to `%2$s` service.", serviceName.getClassName(), methodName);
        buffer.addLine("def %1$s_service", methodName);
        buffer.addLine(  "return %1$s.new(@connection, \"#{@path}/%2$s\")", serviceName.getClassName(), urlSegment);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generatePathLocator(Service service) {
        // Begin method:
        buffer.addLine("##");
        buffer.addLine("# Locates the service corresponding to the given path.");
        buffer.addLine("#");
        buffer.addLine("# @param path [String] The path of the service.");
        buffer.addLine("# @return [Service] A reference to the service.");
        buffer.addLine("#");
        buffer.addLine("def service(path)");
        buffer.addLine(  "if path.nil? || path == ''");
        buffer.addLine(    "return self");
        buffer.addLine(  "end");

        // Generate the code that checks if the path corresponds to any of the locators without parameters:
        service.locators().filter(x -> x.getParameters().isEmpty()).sorted().forEach(locator -> {
            Name name = locator.getName();
            String segment = getPath(name);
            buffer.addLine("if path == '%1$s'", segment);
            buffer.addLine(  "return %1$s_service", rubyNames.getMemberStyleName(name));
            buffer.addLine("end");
            buffer.addLine("if path.start_with?('%1$s/')", segment);
            buffer.addLine(
                "return %1$s_service.service(path[%2$d..-1])",
                rubyNames.getMemberStyleName(name),
                segment.length() + 1
            );
            buffer.addLine("end");
        });

        // If the path doesn't correspond to a locator without parameters, then it will correspond to the locator
        // with parameters, otherwise it is an error:
        Optional<Locator> optional = service.locators().filter(x -> !x.getParameters().isEmpty()).findAny();
        if (optional.isPresent()) {
            Locator locator = optional.get();
            Name name = locator.getName();
            buffer.addLine("index = path.index('/')");
            buffer.addLine("if index.nil?");
            buffer.addLine(  "return %1$s_service(path)", rubyNames.getMemberStyleName(name));
            buffer.addLine("end");
            buffer.addLine(
                "return %1$s_service(path[0..(index - 1)]).service(path[(index +1)..-1])",
                rubyNames.getMemberStyleName(name)
            );
        }
        else {
            buffer.addLine("raise Error.new(\"The path \\\"#{path}\\\" doesn't correspond to any service\")");
        }

        // End method:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateClassDeclaration(Service service) {
        RubyName serviceName = rubyNames.getServiceName(service);
        Service base = service.getBase();
        RubyName baseName = base != null? rubyNames.getServiceName(base): rubyNames.getBaseServiceName();
        buffer.addLine("class %1$s < %2$s", serviceName.getClassName(), baseName.getClassName());
    }

    private String getPath(Name name) {
        return name.words().map(String::toLowerCase).collect(joining());
    }
}
