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

import static java.util.stream.Collectors.joining;
import static java.util.stream.Collectors.toCollection;

import java.io.File;
import java.io.IOException;
import java.util.ArrayDeque;
import java.util.Deque;
import javax.inject.Inject;

import org.ovirt.api.metamodel.concepts.ListType;
import org.ovirt.api.metamodel.concepts.Locator;
import org.ovirt.api.metamodel.concepts.Method;
import org.ovirt.api.metamodel.concepts.Model;
import org.ovirt.api.metamodel.concepts.Name;
import org.ovirt.api.metamodel.concepts.NameParser;
import org.ovirt.api.metamodel.concepts.Parameter;
import org.ovirt.api.metamodel.concepts.Service;
import org.ovirt.api.metamodel.concepts.StructType;
import org.ovirt.api.metamodel.concepts.Type;

/**
 * This class is responsible for generating the classes that represent the services of the model.
 */
public class ServicesGenerator implements RubyGenerator {
    // Well known method names:
    private static final Name GET = NameParser.parseUsingCase("Get");
    private static final Name LIST = NameParser.parseUsingCase("List");
    private static final Name UPDATE = NameParser.parseUsingCase("Update");

    // The directory were the output will be generated:
    protected File out;

    // Reference to the objects used to generate the code:
    @Inject private RubyNames rubyNames;

    // The buffer used to generate the Ruby code:
    private RubyBuffer buffer;

    /**
     * Set the directory were the output will be generated.
     */
    public void setOut(File newOut) {
        out = newOut;
    }

    public void generate(Model model) {
        // Generate a file for each service, and then one large file containing forward declarations of all the services
        // and "load" statements to load them:
        generateServiceFiles(model);
        generateServicesFile(model);
    }

    private void generateServiceFiles(Model model) {
        model.services().forEach(this::generateServiceFile);
    }

    private void generateServiceFile(Service service) {
        // Get the name of the class:
        RubyName serviceName = rubyNames.getServiceName(service);

        // Generate the source:
        buffer = new RubyBuffer();
        buffer.setFileName(serviceName.getFileName());
        generateService(service);
        try {
            buffer.write(out);
        }
        catch (IOException exception) {
            throw new IllegalStateException("Error writing class \"" + serviceName + "\"", exception);
        }
    }

    private void generateService(Service service) {
        // Begin module:
        RubyName serviceName = rubyNames.getServiceName(service);
        buffer.beginModule(serviceName.getModuleName());
        buffer.addLine();

        // Begin class:
        generateClassDeclaration(service);
        buffer.addLine();

        // Generate the constructor:
        buffer.addLine("def initialize(connection, path)");
        buffer.addLine("  @connection = connection");
        buffer.addLine("  @path = path");
        buffer.addLine("end");
        buffer.addLine();

        // Generate the methods and locators:
        service.methods().sorted().forEach(this::generateMethod);
        service.locators().sorted().forEach(this::generateLocator);

        // Generate other methods that don't correspond to model methods or locators:
        generateToS(service);

        // End class:
        buffer.addLine("end");
        buffer.addLine();

        // End module:
        buffer.endModule(serviceName.getModuleName());
    }

    private void generateMethod(Method method) {
        Name name = method.getName();
        if (GET.equals(name) || LIST.equals(name)) {
            generateHttpGet(method);
        }
        else if (UPDATE.equals(name)) {
            generateHttpPut(method);
        }
    }

    private void generateHttpGet(Method method) {
        // Get the output parameter:
        Parameter outParameter = method.parameters().filter(Parameter::isOut).findFirst().orElse(null);

        // Generate the method:
        Name methodName = method.getName();
        buffer.addLine("def %s", rubyNames.getMemberStyleName(methodName));
        if (outParameter != null) {
            Type outType = outParameter.getType();
            buffer.addLine("body = @connection.request({:method => :GET, :path => @path})");
            buffer.addLine("if body then");
            buffer.addLine(  "begin");
            buffer.addLine(    "io = StringIO.new(body)");
            buffer.addLine(    "reader = XmlReader.new({:io => io})");
            if (outType instanceof StructType) {
                RubyName outReader = rubyNames.getReaderName(outType);
                buffer.addLine("return %s.read_one(reader)", outReader.getClassName());
            }
            else if (outType instanceof ListType) {
                ListType outListType = (ListType) outType;
                Type outElementType = outListType.getElementType();
                RubyName outReader = rubyNames.getReaderName(outElementType);
                buffer.addLine("return %s.read_many(reader)", outReader.getClassName());
            }
            buffer.addLine(  "ensure");
            buffer.addLine(    "reader.close");
            buffer.addLine(    "io.close");
            buffer.addLine(  "end");
            buffer.addLine("end");
        }
        else {
            buffer.addLine("@connection.request({:method => :GET, :path => @path})");
        }
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateHttpPut(Method method) {
        // Get the output parameter:
        Parameter inParameter = method.parameters().filter(Parameter::isIn).findFirst().orElse(null);
        Parameter outParameter = method.parameters().filter(Parameter::isOut).findFirst().orElse(null);

        // Generate the method:
        Name methodName = method.getName();
        if (inParameter != null) {
            Name inName = inParameter.getName();
            Type inType = inParameter.getType();
            String inArg = rubyNames.getMemberStyleName(inName);
            buffer.addLine("def %s(%s)", rubyNames.getMemberStyleName(methodName), inArg);
            buffer.addLine(  "io = StringIO.new");
            buffer.addLine(  "writer = XmlWriter.new({:io => io, :indent => true})");
            if (inType instanceof StructType) {
                RubyName inWriter = rubyNames.getWriterName(inType);
                buffer.addLine("%s.write_one(%s, writer)", inWriter.getClassName(), inArg);
            }
            else if (inType instanceof ListType) {
                ListType inListType = (ListType) inType;
                Type inElementType = inListType.getElementType();
                RubyName inWriter = rubyNames.getWriterName(inType);
                buffer.addLine("%s.write_many(%s, writer)", inWriter.getClassName(), inArg);
            }
            buffer.addLine("writer.close");
            buffer.addLine("body = io.string");
        }
        else {
            buffer.addLine("body = nil");
        }
        if (outParameter != null) {
            Type outType = outParameter.getType();
            buffer.addLine("body = @connection.request({:method => :PUT, :path => @path, :body => body})");
            buffer.addLine("if body then");
            buffer.addLine(  "begin");
            buffer.addLine(    "io = StringIO.new(body)");
            buffer.addLine(    "reader = XmlReader.new({:io => io})");
            buffer.addLine(    "reader.read");
            if (outType instanceof StructType) {
                RubyName outReader = rubyNames.getReaderName(outType);
                buffer.addLine("return %s.read_one(reader)", outReader.getClassName());
            }
            else if (outType instanceof ListType) {
                ListType outListType = (ListType) outType;
                Type outElementType = outListType.getElementType();
                RubyName outReader = rubyNames.getReaderName(outElementType);
                buffer.addLine("return %s.read_many(reader)", outReader.getClassName());
            }
            buffer.addLine(  "ensure");
            buffer.addLine(    "reader.close");
            buffer.addLine(    "io.close");
            buffer.addLine(  "end");
            buffer.addLine("end");
        }
        else {
            buffer.addLine("@connection.request({:method => :PUT, :path => @path, :body => body})");
        }
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateToS(Service service) {
        RubyName serviceName = rubyNames.getServiceName(service);
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
        buffer.addLine("def %s(%s)", methodName, argName);
        buffer.addLine(  "return %1$s.new(@connection, \"#{@path}/#{%2$s}\")", serviceName.getClassName(), argName);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateLocatorWithoutParameters(Locator locator) {
        String methodName = rubyNames.getMemberStyleName(locator.getName());
        String urlSegment = locator.getName().words().map(String::toLowerCase).collect(joining());
        RubyName serviceName = rubyNames.getServiceName(locator.getService());
        buffer.addLine("def %1$s", methodName);
        buffer.addLine(  "return %1$s.new(@connection, \"#{@path}/%2$s\")", serviceName.getClassName(), urlSegment);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateServicesFile(Model model) {
        // Calculate the file name:
        String fileName = rubyNames.getModulePath() + "/services";
        buffer = new RubyBuffer();
        buffer.setFileName(fileName);

        // Begin module:
        buffer.addLine("##");
        buffer.addLine("# These forward declarations are required in order to avoid circular dependencies.");
        buffer.addLine("#");
        buffer.beginModule(rubyNames.getModuleName());
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
        buffer.addLine("class %1$s", rubyNames.getBaseServiceName().getClassName());
        buffer.addLine("end");
        buffer.addLine();
        sorted.forEach(x -> {
            generateClassDeclaration(x);
            buffer.addLine("end");
            buffer.addLine();
        });

        // End module:
        buffer.endModule(rubyNames.getModuleName());
        buffer.addLine();

        // Generate the load statements:
        buffer.addLine("##");
        buffer.addLine("# Load all the services.");
        buffer.addLine("#");
        buffer.addLine("load '%1$s.rb'", rubyNames.getBaseServiceName().getFileName());
        model.services()
            .sorted()
            .map(rubyNames::getServiceName)
            .forEach(this::generateLoadStatement);

        // Write the file:
        try {
            buffer.write(out);
        }
        catch (IOException exception) {
            throw new IllegalStateException("Error writing services file \"" + fileName + "\"", exception);
        }
    }

    private void generateClassDeclaration(Service service) {
        RubyName serviceName = rubyNames.getServiceName(service);
        Service base = service.getBase();
        RubyName baseName = base != null? rubyNames.getServiceName(base): rubyNames.getBaseServiceName();
        buffer.addLine("class %1$s < %2$s", serviceName.getClassName(), baseName.getClassName());
    }

    private void generateLoadStatement(RubyName name) {
        buffer.addLine("load '%1$s.rb'", name.getFileName());
    }
}
