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

import java.io.File;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import javax.enterprise.context.ApplicationScoped;
import javax.inject.Inject;

import org.ovirt.api.metamodel.concepts.ListType;
import org.ovirt.api.metamodel.concepts.Name;
import org.ovirt.api.metamodel.concepts.NameParser;
import org.ovirt.api.metamodel.concepts.Service;
import org.ovirt.api.metamodel.concepts.Type;
import org.ovirt.api.metamodel.tool.ReservedWords;
import org.ovirt.api.metamodel.tool.Words;

/**
 * This class contains the rules used to calculate the names of generated Java concepts.
 */
@ApplicationScoped
public class RubyNames {
    // The names of the base classes:
    public static final Name ACTION_NAME = NameParser.parseUsingCase("Action");
    public static final Name FAULT_NAME = NameParser.parseUsingCase("Fault");
    public static final Name LIST_NAME = NameParser.parseUsingCase("List");
    public static final Name READER_NAME = NameParser.parseUsingCase("Reader");
    public static final Name SERVICE_NAME = NameParser.parseUsingCase("Service");
    public static final Name STRUCT_NAME = NameParser.parseUsingCase("Struct");
    public static final Name WRITER_NAME = NameParser.parseUsingCase("Writer");

    // The names of the directories:
    public static final Name READERS_DIR = NameParser.parseUsingCase("Readers");
    public static final Name SERVICES_DIR = NameParser.parseUsingCase("Services");
    public static final Name TYPES_DIR = NameParser.parseUsingCase("Types");
    public static final Name WRITERS_DIR = NameParser.parseUsingCase("Writers");

    // Reference to the object used to do computations with words.
    @Inject private Words words;

    // We need the Ruby reserved words in order to avoid producing names that aren't legal in Java:
    @Inject
    @ReservedWords(language = "ruby")
    private Set<String> reservedWords;

    // The name and path of the module:
    private String moduleName = "OvirtSDK4";
    private String modulePath = "ovirtsdk4";

    // The version of the gem:
    private String version;

    /**
     * Get the module name.
     */
    public String getModuleName() {
        return moduleName;
    }

    /**
     * Get the path of the module.
     */
    public String getModulePath() {
        return modulePath;
    }

    /**
     * Get the version.
     */
    public String getVersion() {
        return version;
    }

    /**
     * Set the versoin.
     */
    public void setVersion(String newVersion) {
        version = newVersion;
    }

    /**
     * Set the module name.
     */
    public void setModuleName(String newModule) {
        // Save the name:
        moduleName = newModule;

        // Calculate the path:
        modulePath = Arrays.stream(moduleName.split("::"))
            .map(String::toLowerCase)
            .collect(joining("/"));
    }

    /**
     * Calculates the Ruby name of the base class of the struct types.
     */
    public RubyName getBaseStructName() {
        return buildName(STRUCT_NAME, null, TYPES_DIR);
    }

    /**
     * Calculates the Ruby name of the base class of the list types.
     */
    public RubyName getBaseListName() {
        return buildName(LIST_NAME, null, TYPES_DIR);
    }

    /**
     * Calculates the Ruby name that corresponds to the given type.
     */
    public RubyName getTypeName(Type type) {
        if (type instanceof ListType) {
            return getBaseListName();
        }
        return buildName(type.getName(), null, TYPES_DIR);
    }

    /**
     * Calculates the Ruby name of the base class of the services.
     */
    public RubyName getBaseServiceName() {
        return buildName(SERVICE_NAME, null, SERVICES_DIR);
    }

    /**
     * Calculates the Ruby name that corresponds to the given service.
     */
    public RubyName getServiceName(Service service) {
        return buildName(service.getName(), SERVICE_NAME, SERVICES_DIR);
    }

    /**
     * Calculates the Ruby name of the base class of the readers.
     */
    public RubyName getBaseReaderName() {
        return buildName(READER_NAME, null, READERS_DIR);
    }

    /**
     * Calculates the Ruby name of the base class of the writers.
     */
    public RubyName getBaseWriterName() {
        return buildName(WRITER_NAME, null, WRITERS_DIR);
    }

    /**
     * Calculates the Ruby name of the reader for the given type.
     */
    public RubyName getReaderName(Type type) {
        return buildName(type.getName(), READER_NAME, READERS_DIR);
    }

    /**
     * Calculates the Ruby name of the writer for the given type.
     */
    public RubyName getWriterName(Type type) {
        return buildName(type.getName(), WRITER_NAME, WRITERS_DIR);
    }

    /**
     * Calculates the Ruby name of the fault class.
     */
    public RubyName getFaultName() {
        return buildName(FAULT_NAME, null, TYPES_DIR);
    }

    /**
     * Calculates the Ruby name of the fault reader.
     */
    public RubyName getFaultReaderName() {
        return buildName(FAULT_NAME, READER_NAME, READERS_DIR);
    }

    /**
     * Calculates the Ruby name of the action class.
     */
    public RubyName getActionName() {
        return buildName(ACTION_NAME, null, TYPES_DIR);
    }

    /**
     * Calculates the Ruby name of the action reader.
     */
    public RubyName getActionReaderName() {
        return buildName(ACTION_NAME, READER_NAME, READERS_DIR);
    }

    /**
     * Builds a Ruby name from the given base name and suffix, and a directory.
     *
     * The suffix can be {@code null} or empty, in that case then won't be added.
     *
     * If the {@code directory} parameter is given then it will be appended to the file associated to the name. For
     * example, if the {@code directory} parameter is {@code types} then the file will be {@code ovirt/lib/types}.
     *
     * @param base the base name
     * @param suffix the suffix to add to the name
     * @param directory the directory associated to the name
     * @return the calculated Ruby name
     */
    private RubyName buildName(Name base, Name suffix, Name directory) {
        // Calculate class name:
        List<String> words = base.getWords();
        if (suffix != null) {
            words.addAll(suffix.getWords());
        }
        Name name = new Name(words);
        RubyName result = new RubyName();
        result.setClassName(getClassStyleName(name));

        // Calculate the module name:
        result.setModuleName(moduleName);

        // Calculate the file name:
        StringBuilder fileName = new StringBuilder();
        fileName.append(modulePath);
        fileName.append(File.separator);
        if (directory != null) {
            fileName.append(getFileStyleName(directory));
            fileName.append(File.separator);
        }
        fileName.append(getFileStyleName(name));
        result.setFileName(fileName.toString());

        return result;
    }

    /**
     * Returns a representation of the given name using the capitalization style typically used for Ruby classes.
     */
    public String getClassStyleName(Name name) {
        return name.words().map(words::capitalize).collect(joining());
    }

    /**
     * Returns a representation of the given name using the capitalization style typically used for Ruby members.
     */
    public String getMemberStyleName(Name name) {
        String result = name.words().map(String::toLowerCase).collect(joining("_"));
        if (reservedWords.contains(result)) {
            result += "_";
        }
        return result;
    }

    /**
     * Returns a representation of the given name using the capitalization style typically used for Ruby constants.
     */
    public String getConstantStyleName(Name name) {
        return name.words().map(String::toUpperCase).collect(joining("_"));
    }

    /**
     * Returns a representation of the given name using the capitalization style typically used for Ruby files.
     */
    public String getFileStyleName(Name name) {
        return name.words().map(String::toLowerCase).collect(joining("_"));
    }
}

