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

import static java.util.stream.Collectors.joining;
import static java.util.stream.Collectors.toCollection;
import static java.util.stream.Collectors.toList;

import java.io.File;
import java.io.IOException;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.Optional;
import javax.enterprise.inject.spi.CDI;
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
import org.ovirt.api.metamodel.tool.Names;
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
    @Inject private Names names;
    @Inject private RubyNames rubyNames;
    @Inject private SchemaNames schemaNames;

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
        buffer = CDI.current().select(RubyBuffer.class).get();
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
        buffer.addComment();
        buffer.addComment("These forward declarations are required in order to avoid circular dependencies.");
        buffer.addComment();
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

        // Generate the service methods:
        service.methods()
            .sorted()
            .forEach(this::generateMethod);

        // Generate the locator methods:
        service.locators()
            .sorted()
            .forEach(this::generateLocator);

        // Generate the path locator:
        generatePathLocator(service);

        // Generate other methods that don't correspond to model methods or locators:
        generateToS(service);

        // End class:
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateMethod(Method method) {
        Method base = getDeepestBase(method);
        Name name = base.getName();
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
        // Classify the parameters, as they have different treatment. The primary parameter will be the request body and
        // the secondary parameters will be query parameters.
        Parameter primaryParameter = getPrimaryParameter(method);
        List<Parameter> secondaryParameters = getSecondaryParameters(method);

        // Generate the parameter specs:
        Name methodName = getFullName(method);
        String specConstant = rubyNames.getConstantStyleName(methodName);
        generateParameterSpecs(specConstant, secondaryParameters);

        // Document the method:
        Type primaryParameterType = primaryParameter.getType();
        Name primaryParameterName = primaryParameter.getName();
        RubyName argType = rubyNames.getTypeName(primaryParameterType);
        String argName = rubyNames.getMemberStyleName(primaryParameterName);
        String methodDoc = method.getDoc();
        if (methodDoc == null) {
            methodDoc = String.format("Adds a new `%1$s`.", argName);
        }
        buffer.addComment();
        buffer.addComment(methodDoc);
        buffer.addComment();

        // Document the primary parameter:
        String primaryParameterDoc = primaryParameter.getDoc();
        if (primaryParameterDoc == null) {
            primaryParameterDoc = String.format("The `%1$s` to add.", argName);
        }
        buffer.addYardParam(primaryParameter, primaryParameterDoc);
        buffer.addComment();

        // Document the secondary parameters:
        buffer.addYardTag("param", "opts [Hash] Additional options.");
        buffer.addComment();
        secondaryParameters.forEach(parameter -> {
            buffer.addYardOption(parameter);
            buffer.addComment();
        });

        // Document builtin parameters:
        documentBuiltinParameters();

        // Document the return value:
        buffer.addYardReturn(primaryParameter);
        buffer.addComment();

        // Generate the method declaration:
        buffer.addLine("def %1$s(%2$s, opts = {})", rubyNames.getMemberStyleName(methodName), argName);
        buffer.addLine(  "internal_add(%1$s, %2$s, %3$s, opts)", argName, argType.getClassName(), specConstant);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateActionHttpPost(Method method) {
        // Get the input parameters:
        List<Parameter> inputParameters = method.parameters()
            .filter(Parameter::isIn)
            .sorted()
            .collect(toList());

        // Get the name of output parameter:
        String resultName = method.parameters()
            .filter(Parameter::isOut)
            .findFirst()
            .map(Parameter::getName)
            .map(rubyNames::getMemberStyleName)
            .orElse(null);

        // Generate the parameter specs:
        Name methodName = getFullName(method);
        String specConstant = rubyNames.getConstantStyleName(methodName);
        generateParameterSpecs(specConstant, inputParameters);

        // Document the method:
        String actionName = rubyNames.getMemberStyleName(methodName);
        String methodDoc = method.getDoc();
        if (methodDoc == null) {
            methodDoc = String.format("Executes the `%1$s` method.", actionName);
        }
        buffer.addComment();
        buffer.addComment(methodDoc);
        buffer.addComment();

        // Document the parameters:
        buffer.addYardTag("param", "opts [Hash] Additional options.");
        buffer.addComment();
        method.parameters().sorted().forEach(parameter -> {
            buffer.addYardOption(parameter);
            buffer.addComment();
        });

        // Document builtin parameters:
        documentBuiltinParameters();

        // Generate the method declaration:
        Method deepestBase = getDeepestBase(method);
        Name deepestBaseName = deepestBase.getName();
        String actionPath = getPath(deepestBaseName);
        String resultArg = resultName != null? ":" + resultName: "nil";
        buffer.addLine("def %1$s(opts = {})", actionName);
        buffer.addLine(  "internal_action(:%1$s, %2$s, %3$s, opts)", actionPath, resultArg, specConstant);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateHttpGet(Method method) {
        // Get input and output parameters:
        List<Parameter> inParameters = method.parameters()
            .filter(Parameter::isIn)
            .sorted()
            .collect(toList());
        List<Parameter> outParameters = method.parameters()
            .filter(Parameter::isOut)
            .sorted()
            .collect(toList());

        // Get the first output parameter:
        Parameter mainParameter = outParameters.stream()
            .findFirst()
            .orElse(null);

        // Generate the parameters spec:
        Name methodName = getFullName(method);
        String specConstant = rubyNames.getConstantStyleName(methodName);
        generateParameterSpecs(specConstant, inParameters);

        // Document the method:
        buffer.addComment();
        String methodDoc = method.getDoc();
        if (methodDoc == null) {
            methodDoc = "Returns the representation of the object managed by this service.";
        }
        buffer.addComment(methodDoc);
        buffer.addComment();

        // Document the parameters:
        buffer.addYardTag("param", "opts [Hash] Additional options.");
        buffer.addComment();
        inParameters.forEach(parameter -> {
            buffer.addYardOption(parameter);
            buffer.addComment();
        });

        // Document builtin parameters:
        documentBuiltinParameters();

        // Document the return value:
        buffer.addYardReturn(mainParameter);
        buffer.addComment();

        // Generate the method declaration:
        buffer.addLine("def %1$s(opts = {})", rubyNames.getMemberStyleName(methodName));
        buffer.addLine(  "internal_get(%1$s, opts)", specConstant);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateHttpPut(Method method) {
        // Classify the parameters, as they have different treatment. The primary parameter will be the request body and
        // the secondary parameters will be query parameters.
        Parameter primaryParameter = getPrimaryParameter(method);
        List<Parameter> secondaryParameters = getSecondaryParameters(method);

        // Generate the parameters spec:
        Name methodName = getFullName(method);
        String specConstant = rubyNames.getConstantStyleName(methodName);
        generateParameterSpecs(specConstant, secondaryParameters);

        // Document the method:
        Type primaryParameterType = primaryParameter.getType();
        Name primaryParameterName = primaryParameter.getName();
        RubyName argType = rubyNames.getTypeName(primaryParameterType);
        String argName = rubyNames.getMemberStyleName(primaryParameterName);
        String methodDoc = method.getDoc();
        if (methodDoc == null) {
            methodDoc = String.format("Updates the `%1$s`.", argName);
        }
        buffer.addComment();
        buffer.addComment(methodDoc);
        buffer.addComment();

        // Document the primary parameter:
        String primaryParameterDoc = primaryParameter.getDoc();
        if (primaryParameterDoc == null) {
            primaryParameterDoc = String.format("The `%1$s` to update.", argName);
        }
        buffer.addYardParam(primaryParameter, primaryParameterDoc);

        // Document the secondary parameters:
        buffer.addYardTag("param", "opts [Hash] Additional options.");
        buffer.addComment();
        secondaryParameters.forEach(parameter -> {
            buffer.addYardOption(parameter);
            buffer.addComment();
        });

        // Document builtin parameters:
        documentBuiltinParameters();

        // Document the return value:
        buffer.addYardReturn(primaryParameter);
        buffer.addComment();

        // Generate the method declaration:
        buffer.addLine("def %1$s(%2$s, opts = {})", rubyNames.getMemberStyleName(methodName), argName);
        buffer.addLine(  "internal_update(%1$s, %2$s, %3$s, opts)", argName, argType.getClassName(), specConstant);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateHttpDelete(Method method) {
        // Get input parameters:
        List<Parameter> inParameters = method.parameters()
            .filter(Parameter::isIn)
            .sorted()
            .collect(toList());

        // Generate the parameters spec:
        Name methodName = getFullName(method);
        String specConstant = rubyNames.getConstantStyleName(methodName);
        generateParameterSpecs(specConstant, inParameters);

        // Document the method:
        String methodDoc = method.getDoc();
        if (methodDoc == null) {
            methodDoc = "Deletes the object managed by this service.";
        }
        buffer.addComment();
        buffer.addComment(methodDoc);
        buffer.addComment();

        // Document the parameters:
        buffer.addYardTag("param", "opts [Hash] Additional options.");
        buffer.addComment();
        inParameters.forEach(buffer::addYardOption);

        // Document builtin parameters:
        documentBuiltinParameters();

        // Generate the method declaration:
        buffer.addLine("def %1$s(opts = {})", rubyNames.getMemberStyleName(methodName));
        buffer.addLine(  "internal_remove(%1$s, opts)", specConstant);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateParameterSpecs(String constant, List<Parameter> parameters) {
        buffer.addLine("%1$s = [", constant);
        parameters.forEach(this::generateParameterSpec);
        buffer.addLine("].freeze");
        buffer.addLine();
        buffer.addLine("private_constant :%1$s", constant);
        buffer.addLine();
    }

    private void generateParameterSpec(Parameter parameter) {
        Type type = parameter.getType();
        Name name = parameter.getName();
        String symbol = rubyNames.getMemberStyleName(name);
        String clazz = null;
        if (type instanceof PrimitiveType) {
            Model model = type.getModel();
            if (type == model.getStringType()) {
                clazz = "String";
            }
            else if (type == model.getBooleanType()) {
                clazz = "TrueClass";
            }
            else if (type == model.getIntegerType()) {
                clazz = "Integer";
            }
            else if (type == model.getDecimalType()) {
                clazz = "Float";
            }
            else if (type == model.getDateType()) {
                clazz = "DateTime";
            }
            else {
                throw new IllegalArgumentException(
                    "Don't know how to generate the parameter spec for type \"" + type + "\""
                );
            }
        }
        else if (type instanceof StructType) {
            clazz = rubyNames.getTypeName(type).getClassName();
        }
        else if (type instanceof ListType) {
            clazz = "List";
        }
        if (clazz != null) {
            buffer.addLine("[:%1$s, %2$s].freeze,", symbol, clazz);
        }
    }

    private void generateToS(Service service) {
        RubyName serviceName = rubyNames.getServiceName(service);
        buffer.addComment();
        buffer.addComment("Returns an string representation of this service.");
        buffer.addComment();
        buffer.addYardTag("return", "[String]");
        buffer.addComment();
        buffer.addLine("def to_s");
        buffer.addLine(  "\"#<#{%1$s}:#{absolute_path}>\"", serviceName.getClassName());
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
        String doc = locator.getDoc();
        if (doc == null) {
            doc = String.format("Locates the `%1$s` service.", methodName);
        }
        buffer.addComment();
        buffer.addComment(doc);
        buffer.addComment();
        buffer.addYardTag("param", "%1$s [String] The identifier of the `%2$s`.", argName, methodName);
        buffer.addComment();
        buffer.addYardTag("return", "[%1$s] A reference to the `%2$s` service.", serviceName.getClassName(), methodName);
        buffer.addComment();
        buffer.addLine("def %1$s_service(%2$s)", methodName, argName);
        buffer.addLine(  "%1$s.new(self, %2$s)", serviceName.getClassName(), argName);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generateLocatorWithoutParameters(Locator locator) {
        String methodName = rubyNames.getMemberStyleName(locator.getName());
        String urlSegment = getPath(locator.getName());
        RubyName serviceName = rubyNames.getServiceName(locator.getService());
        String doc = locator.getDoc();
        if (doc == null) {
            doc = String.format("Locates the `%1$s` service.", methodName);
        }
        buffer.addComment();
        buffer.addComment(doc);
        buffer.addComment();
        buffer.addYardTag("return", "[%1$s] A reference to `%2$s` service.", serviceName.getClassName(), methodName);
        buffer.addComment();
        buffer.addLine("def %1$s_service", methodName);
        buffer.addLine(  "@%1$s_service ||= %2$s.new(self, '%3$s')", methodName, serviceName.getClassName(), urlSegment);
        buffer.addLine("end");
        buffer.addLine();
    }

    private void generatePathLocator(Service service) {
        // Begin method:
        buffer.addComment();
        buffer.addComment("Locates the service corresponding to the given path.");
        buffer.addComment();
        buffer.addYardTag("param", "path [String] The path of the service.");
        buffer.addComment();
        buffer.addYardTag("return", "[Service] A reference to the service.");
        buffer.addComment();
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

    private void documentBuiltinParameters() {
        // Additional headers:
        buffer.addYardTag("option", "opts [Hash] :headers ({}) Additional HTTP headers.");
        buffer.addComment();

        // Additional query parameter:
        buffer.addYardTag("option", "opts [Hash] :query ({}) Additional URL query parameters.");
        buffer.addComment();

        // Request specific timeout:
        buffer.addYardTag(
            "option",
            "opts [Integer] :timeout (nil) The timeout for this request, in seconds. If no value is explicitly \n" +
            "given then the timeout set globally for the connection will be used."
        );
        buffer.addComment();

        // Wait flag:
        buffer.addYardTag("option", "opts [Boolean] :wait (true) If `true` wait for the response.");
        buffer.addComment();
    }

    private String getPath(Name name) {
        return name.words().map(String::toLowerCase).collect(joining());
    }

    /**
     * Returns the primary parameter of the given method. The primary parameter is the one that is used in the request
     * body for methods like {@code add} and {@code update}, it is usually the first parameter that is both used for
     * input and output and whose type isn't primitive.
     */
    private Parameter getPrimaryParameter(Method method) {
        return method.parameters()
            .filter(parameter -> parameter.isIn() && parameter.isOut())
            .filter(parameter -> !(parameter.getType() instanceof PrimitiveType))
            .findFirst()
            .orElse(null);
    }

    /**
     * Returns the list of secondary parameters of the given methods. The secondary parameters are those that will be
     * used as query or matrix parameters, they should be used for input only, and their type must be primitive.
     */
    private List<Parameter> getSecondaryParameters(Method method) {
        return method.parameters()
            .filter(parameter -> parameter.isIn() && !parameter.isOut())
            .filter(parameter -> parameter.getType() instanceof PrimitiveType)
            .sorted()
            .collect(toList());
    }

    /**
     * Returns the deepest base of the given method, the one that doesn't have a base itself.
     */
    private Method getDeepestBase(Method method) {
        Method base = method.getBase();
        if (base == null) {
            return method;
        }
        return getDeepestBase(base);
    }

    /**
     * Calculates the full name of a method, taking into account that the method may extend other method. For this kind
     * of methods the full name wil be the name of the base, followed by the name of the method. For example, if the
     * name of the base is {@code Add} and the name of the method is {@code FromSnapsot} then the full method name will
     * be {@code AddFromSnapshot}.
     */
    private Name getFullName(Method method) {
        Method base = method.getBase();
        if (base == null) {
            return method.getName();
        }
        return names.concatenate(getFullName(base), method.getName());
    }
}
