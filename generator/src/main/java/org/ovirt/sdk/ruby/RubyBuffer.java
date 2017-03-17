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

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.Deque;
import java.util.Formatter;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import javax.enterprise.context.Dependent;
import javax.inject.Inject;

import org.apache.commons.io.FileUtils;
import org.ovirt.api.metamodel.concepts.Parameter;

/**
 * This class is a buffer intended to simplify generation of Ruby source code. It stores the name of the module, the
 * list of requires and the rest of the source separately, so that requires can be added on demand while generating the
 * rest of the source.
 */
@Dependent
public class RubyBuffer {
    // Reference to the object used to generate Ruby names:
    @Inject private RubyNames rubyNames;
    @Inject private YardDoc yardDoc;

    // The name of the file:
    private String fileName;

    // The things to be required, without the "required" keyword and quotes.
    private Set<String> requires = new HashSet<>();

    // The stack of module names:
    private Deque<String> moduleStack = new ArrayDeque<>();

    // The lines of the body of the class:
    private List<String> lines = new ArrayList<>();

    // The current indentation level:
    private int level;

    /**
     * Sets the file name.
     */
    public void setFileName(String newFileName) {
        fileName = newFileName;
    }

    /**
     * Begins the given module name, which may be separated with {@code ::}, and writes the corresponding {@code module}
     * statements.
     */
    public void beginModule(String moduleName) {
        Arrays.stream(moduleName.split("::")).forEach(x -> {
            moduleStack.push(x);
            addLine("module %1$s", x);
        });
    }

    /**
     * Ends the given module name, which may be separated with {@code ::}, and writes the corresponding {@code end}
     * statements.
     */
    public void endModule(String moduleName) {
        Arrays.stream(moduleName.split("::")).forEach(x -> {
            addLine("end");
            moduleStack.pop();
        });
    }

    /**
     * Adds a line to the file. If the line contains new line characters then it will be broken and multiple lines and
     * each one will be processed in sequence. For example, if these lines aren't indented, the result will be indented
     * anyhow.
     */
    public void addLine(String line) {
        if (line != null) {
            String[] parts = line.split("\\n");
            for (String part : parts) {
                addLineNoSplit(part);
            }
        }
    }

    /**
     * Adds a line to the file without taking into account new line characters.
     */
    private void addLineNoSplit(String line) {
        // Check of the line is the begin or end of a block:
        boolean isBegin =
            line.endsWith("(") ||
            line.endsWith("[") ||
            line.endsWith("|") ||
            line.equals("begin") ||
            line.equals("else") ||
            line.equals("ensure") ||
            line.startsWith("case ") ||
            line.startsWith("class ") ||
            line.startsWith("def ") ||
            line.startsWith("if ") ||
            line.startsWith("loop ") ||
            line.startsWith("module ") ||
            line.startsWith("unless ") ||
            line.startsWith("when ") ||
            line.startsWith("while ");
        boolean isEnd =
            line.equals(")") ||
            line.equals("else") ||
            line.equals("else") ||
            line.equals("end") ||
            line.equals("ensure") ||
            line.startsWith("]") ||
            line.startsWith("when ");

        // Decrease the indentation if the line is the end of a block:
        if (isEnd) {
            if (level > 0) {
                level--;
            }
        }

        // Indent the line and add it to the list:
        StringBuilder buffer = new StringBuilder(level * 2 + line.length());
        for (int i = 0; i < level; i++) {
            buffer.append("  ");
        }
        buffer.append(line);
        line = buffer.toString();
        lines.add(line);

        // Increase the indentation if the line is the begin of a block:
        if (isBegin) {
            level++;
        }
    }

    /**
     * Adds an empty line to the body of the class.
     */
    public void addLine() {
        addLine("");
    }

    /**
     * Adds a formatted line to the file. The given {@code args} are formatted using the provided {@code format} using
     * the {@link String#format(String, Object...)} method.
     */
    public void addLine(String format, Object ... args) {
        StringBuilder buffer = new StringBuilder();
        Formatter formatter = new Formatter(buffer);
        formatter.format(format, args);
        String line = buffer.toString();
        addLine(line);
    }

    /**
     * Adds a comment to the file. If the line contains new line characters then it will be broken and multiple lines
     * and each one will be processed in sequence. For example, if these lines aren't indented, the result will be
     * indented anyhow.
     */
    public void addComment(String line) {
        if (line != null) {
            String[] parts = line.split("\\n");
            for (String part : parts) {
                addCommentNoSplit(part);
            }
        }
    }

    /**
     * Adds a comment to the file without taking into account new line characters.
     */
    private void addCommentNoSplit(String line) {
        StringBuilder buffer = new StringBuilder(2 + level * 2 + line.length());
        for (int i = 0; i < level; i++) {
            buffer.append("  ");
        }
        buffer.append("# ");
        buffer.append(line);
        line = buffer.toString();
        lines.add(line);
    }

    /**
     * Adds an empty comment to the file.
     */
    public void addComment() {
        addComment("");
    }

    /**
     * Adds a formatted comment to the file. The given {@code args} are formatted using the provided {@code format}
     * using the {@link String#format(String, Object...)} method.
     */
    public void addComment(String format, Object ... args) {
        StringBuilder buffer = new StringBuilder();
        Formatter formatter = new Formatter(buffer);
        formatter.format(format, args);
        String line = buffer.toString();
        addComment(line);
    }

    /**
     * Adds a formatted comment tag to the file. The given {@code args} are formatted using the provided {@code format}
     * using the {@link String#format(String, Object...)} method. The lines of the comment will be indented so that
     * the <i>Yard</i> documentation processor will understand that they belong to the same tag.
     *
     * @param tag the name of the <i>Yard</i> tag, for example {@code param} or {@code option}
     * @param format the format string used to create the text of the tag
     * @param args the arguments used to create the text of the tag
     */
    public void addYardTag(String tag, String format, Object ... args) {
        // Format the text and split it into lines:
        StringBuilder text = new StringBuilder();
        Formatter formatter = new Formatter(text);
        formatter.format(format, args);
        String[] lines = text.toString().split("\\n");

        // The first line must be prefixed with the name of the tag:
        StringBuilder first = new StringBuilder();
        first.append("@");
        first.append(tag);
        if (!lines[0].isEmpty()) {
            first.append(" ");
            first.append(lines[0]);
        }
        addComment(first.toString());

        // The rest of the lines need to be indented with two spaces, so that Yard will consider them part of the tag:
        for (int i = 1; i < lines.length; i++) {
            StringBuilder line = new StringBuilder(2 + lines[i].length());
            line.append("  ");
            line.append(lines[i]);
            addComment(line.toString());
        }
    }

    /**
     * Adds a comment containing a Yard {@code @param} tag for the given parameter.
     */
    public void addYardParam(Parameter parameter) {
        addYardParam(parameter, null);
    }

    /**
     * Adds a comment containing a Yard {@code @param} tag for the given parameter.
     */
    public void addYardParam(Parameter parameter, String doc) {
        if (doc == null) {
            doc = parameter.getDoc();
        }
        if (doc == null) {
            doc = "";
        }
        addYardTag(
            "param",
            "%1$s [%2$s] %3$s",
            rubyNames.getMemberStyleName(parameter.getName()),
            yardDoc.getType(parameter.getType()),
            doc
        );
    }

    /**
     * Adds a comment containing a Yard {@code @option} tag for the given parameter.
     */
    public void addYardOption(Parameter parameter) {
        addYardOption(parameter, null);
    }

    /**
     * Adds a comment containing a Yard {@code @option} tag for the given parameter.
     */
    public void addYardOption(Parameter parameter, String doc) {
        if (doc == null) {
            doc = parameter.getDoc();
        }
        if (doc == null) {
            doc = "";
        }
        addYardTag(
            "option",
            "opts [%1$s] :%2$s %3$s",
            yardDoc.getType(parameter.getType()),
            rubyNames.getMemberStyleName(parameter.getName()),
            doc
        );
    }

    /**
     * Adds a comment containing a Yard {@code @return} tag for the given parameter.
     */
    public void addYardReturn(Parameter parameter) {
        addYardTag(
            "return",
            "[%1$s]",
            yardDoc.getType(parameter.getType())
        );
    }

    /**
     * Generates the complete source code of the class.
     */
    public String toString() {
        StringBuilder buffer = new StringBuilder();

        // License:
        buffer.append("#\n");
        buffer.append("# Copyright (c) 2015-2016 Red Hat, Inc.\n");
        buffer.append("#\n");
        buffer.append("# Licensed under the Apache License, Version 2.0 (the \"License\");\n");
        buffer.append("# you may not use this file except in compliance with the License.\n");
        buffer.append("# You may obtain a copy of the License at\n");
        buffer.append("#\n");
        buffer.append("#   http://www.apache.org/licenses/LICENSE-2.0\n");
        buffer.append("#\n");
        buffer.append("# Unless required by applicable law or agreed to in writing, software\n");
        buffer.append("# distributed under the License is distributed on an \"AS IS\" BASIS,\n");
        buffer.append("# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.\n");
        buffer.append("# See the License for the specific language governing permissions and\n");
        buffer.append("# limitations under the License.\n");
        buffer.append("#\n");
        buffer.append("\n");

        // Require:
        List<String> requiresList = new ArrayList<>(requires);
        Collections.sort(requiresList);
        for (String requiresItem : requiresList) {
            buffer.append("require '");
            buffer.append(requiresItem);
            buffer.append("'\n");
        }
        buffer.append("\n");

        // Body:
        for (String line : lines) {
            buffer.append(line);
            buffer.append("\n");
        }

        return buffer.toString();
    }

    /**
     * Creates a {@code .rb} source file and writes the source. The required intermediate directories will be created
     * if they don't exist.
     *
     * @param dir the base directory for the source code
     * @throws IOException if something fails while creating or writing the file
     */
    public void write(File dir) throws IOException {
        // Calculate the complete fille name:
        File file = new File(dir, fileName.replace('/', File.separatorChar) + ".rb");

        // Create the directory and all its parent if needed:
        File parent = file.getParentFile();
        FileUtils.forceMkdir(parent);

        // Write the file:
        System.out.println("Writing file \"" + file.getAbsolutePath() + "\".");
        try (Writer writer = new OutputStreamWriter(new FileOutputStream(file), StandardCharsets.UTF_8)) {
            writer.write(toString());
        }
    }
}
