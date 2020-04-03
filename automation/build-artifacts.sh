#!/usr/bin/bash -xe

export PYTHON=python3
export JAVA_HOME="${JAVA_HOME:=/usr/lib/jvm/java-11}"

${PYTHON} automation/build.py
