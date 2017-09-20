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

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;
import javax.annotation.PostConstruct;
import javax.enterprise.inject.Produces;
import javax.inject.Singleton;

import org.ovirt.api.metamodel.tool.ReservedWords;

/**
 * This class is a producer of the set of Java reserved words.
 */
@Singleton
public class RubyReservedWords {
    private Set<String> words;

    @PostConstruct
    private void init() {
        // Create the set:
        words = new HashSet<>();

        // Populate the set:
        words.add("alias");
        words.add("and");
        words.add("begin");
        words.add("break");
        words.add("case");
        words.add("class");
        words.add("def");
        words.add("defined?");
        words.add("do");
        words.add("else");
        words.add("elsif");
        words.add("end");
        words.add("ensure");
        words.add("false");
        words.add("for");
        words.add("if");
        words.add("in");
        words.add("module");
        words.add("next");
        words.add("nil");
        words.add("not");
        words.add("or");
        words.add("redo");
        words.add("rescue");
        words.add("retry");
        words.add("return");
        words.add("self");
        words.add("super");
        words.add("then");
        words.add("true");
        words.add("undef");
        words.add("unless");
        words.add("until");
        words.add("when");
        words.add("while");
        words.add("yield");
        words.add("END");

        // Wrap the set so that it is unmodifiable:
        words = Collections.unmodifiableSet(words);
    }

    /**
     * Produces the set of Ruby reserved words.
     */
    @Produces
    @ReservedWords(language = "ruby")
    public Set<String> getWords() {
        return words;
    }
}
