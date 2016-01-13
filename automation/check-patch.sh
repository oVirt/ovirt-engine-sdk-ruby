#!/bin/sh -ex

# Create a settings file that uses the our artifactory server as
# proxy for all repositories:
settings="$(pwd)/settings.xml"
cat > "${settings}" <<.
<settings>
  <mirrors>

    <mirror>
      <id>ovirt-artifactory</id>
      <url>http://artifactory.ovirt.org/artifactory/ovirt-mirror</url>
      <mirrorOf>*</mirrorOf>
    </mirror>

    <mirror>
      <id>maven-central</id>
      <url>http://repo.maven.apache.org/maven2</url>
      <mirrorOf>*</mirrorOf>
    </mirror>

  </mirrors>
</settings>
.

# There may be several versions of Java installed in the build
# enviroment, and we need to make sure that Java 8 is used, as
# it is required by the code generator:
export JAVA_HOME="${JAVA_HOME:=/usr/lib/jvm/java-1.8.0}"

# Build and run the tests:
mvn test -s "${settings}"
