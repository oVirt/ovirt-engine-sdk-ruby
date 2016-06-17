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
import javax.enterprise.context.ApplicationScoped;
import javax.enterprise.inject.Any;
import javax.enterprise.inject.Instance;
import javax.inject.Inject;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
import org.apache.commons.io.FileUtils;
import org.ovirt.api.metamodel.analyzer.ModelAnalyzer;
import org.ovirt.api.metamodel.concepts.Model;
import org.ovirt.api.metamodel.tool.BuiltinTypes;

@ApplicationScoped
public class Tool {
    // The names of the command line options:
    private static final String MODEL_OPTION = "model";
    private static final String OUT_OPTION = "out";
    private static final String VERSION_OPTION = "version";

    // Reference to the objects used to calculate Ruby names:
    @Inject private RubyNames rubyNames;

    // References to the generators:
    @Inject @Any
    private Instance<RubyGenerator> generators;

    // Reference to the object used to add built-in types to the model:
    @Inject private BuiltinTypes builtinTypes;

    public void run(String[] args) throws Exception {
        // Create the command line options:
        Options options = new Options();

        // Options for the locations of files and directories:
        options.addOption(Option.builder()
            .longOpt(MODEL_OPTION)
            .desc("The directory or .jar file containing the source model files.")
            .type(File.class)
            .required(true)
            .hasArg(true)
            .argName("DIRECTORY|JAR")
            .build()
        );

        // Options for the location of the generated Ruby sources:
        options.addOption(Option.builder()
            .longOpt(OUT_OPTION)
            .desc("The directory where the generated Ruby source will be created.")
            .type(File.class)
            .required(false)
            .hasArg(true)
            .argName("DIRECTORY")
            .build()
        );

        // Option to specify the version number of the gem:
        options.addOption(Option.builder()
            .longOpt(VERSION_OPTION)
            .desc("The the version number of the SDK, for example \"4.0.0.Alpha0\".")
            .type(File.class)
            .required(true)
            .hasArg(true)
            .argName("VERSION")
            .build()
        );

        // Parse the command line:
        CommandLineParser parser = new DefaultParser();
        CommandLine line = null;
        try {
            line = parser.parse(options, args);
        }
        catch (ParseException exception) {
            HelpFormatter formatter = new HelpFormatter();
            formatter.setSyntaxPrefix("Usage: ");
            formatter.printHelp("ruby-tool [OPTIONS]", options);
            System.exit(1);
        }

        // Extract the locations of files and directories from the command line:
        File modelFile = (File) line.getParsedOptionValue(MODEL_OPTION);
        File outDir = (File) line.getParsedOptionValue(OUT_OPTION);

        // Extract the version of the:
        String version = line.getOptionValue(VERSION_OPTION);

        // The version will usually come from the root POM of the project, where it will use upper case for suffixes
        // like "Alpha" or "Beta". In addition it will have the "-SNAPSHOT" suffix for non release versions. We need
        // to remove the "-SNAPSHOT" suffix, and convert the result to lower case, as the common practice for Ruby
        // is to use "alpha" or "beta", lower case.
        version = version.replaceAll("-SNAPSHOT$", "").toLowerCase();

        // Analyze the model files:
        Model model = new Model();
        ModelAnalyzer modelAnalyzer = new ModelAnalyzer();
        modelAnalyzer.setModel(model);
        modelAnalyzer.analyzeSource(modelFile);

        // Add the built-in types:
        builtinTypes.addBuiltinTypes(model);

        // Configure the object used to generate names:
        rubyNames.setVersion(version);

        // Run the generators:
        if (outDir != null) {
            FileUtils.forceMkdir(outDir);
            for (RubyGenerator generator : generators) {
                generator.setOut(outDir);
                generator.generate(model);
            }
        }
    }
}
