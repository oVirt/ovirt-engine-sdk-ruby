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
import javax.enterprise.inject.spi.CDI;
import javax.inject.Inject;

import org.ovirt.api.metamodel.concepts.Model;

/**
 * This class is responsible for generating the file that contains the version number information.
 */
public class VersionGenerator implements RubyGenerator {
    // The directory were the output will be generated:
    protected File out;

    // Reference to the objects used to generate the code:
    @Inject private RubyNames rubyNames;

    // The buffer used to generate the Ruby code:
    private RubyBuffer buffer;

    public void setOut(File newOut) {
        out = newOut;
    }

    public void generate(Model model) throws IOException {
        // Generate the source:
        buffer = CDI.current().select(RubyBuffer.class).get();
        buffer.setFileName(rubyNames.getModulePath() + File.separator + "version");
        generateVersion();
        try {
            buffer.write(out);
        }
        catch (IOException exception) {
            throw new IllegalStateException("Error writing version file", exception);
        }
    }

    public void generateVersion() {
        String moduleName = rubyNames.getModuleName();
        String version = rubyNames.getVersion();
        buffer.beginModule(moduleName);
        buffer.addLine("VERSION = '%1$s'", version.toLowerCase());
        buffer.endModule(moduleName);
    }
}

