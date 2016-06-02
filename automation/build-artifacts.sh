#!/bin/sh -ex

# Clean and then create the artifacts directory:
rm -rf exported-artifacts
mkdir -p exported-artifacts

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

# Calculate a gem version number that includes the git hash and
# the date:
date="$(date --utc +%Y%m%d)"
commit="$(git log -1 --pretty=format:%h)"
#suffix=".${date}git${commit}"
suffix=".alpha13"

# Build the SDK code generator, run it, and build the gem:
mvn package -s "${settings}" -Dgem.suffix="${suffix}"

# Find the generated .gem file:
gem_file="$(find . -type f -name "*-*${suffix}.gem" -print -quit)"

# Build the RPM:
cp "${gem_file}" packaging/
pushd packaging
  export gem_version="$(echo ${gem_file} | sed -e 's/^.*-//' -e 's/\.gem//')"
  export gem_url="$(basename ${gem_file})"
  #export rpm_release="0.0${suffix}$(rpm --eval '%dist')"
  export rpm_release="0.13${suffix}$(rpm --eval '%dist')"
  ./build.sh
popd

# Copy the .gem and .rpm files to the exported artifacts directory:
for file in $(find . -type f -regex '.*\.\(gem\|rpm\)'); do
  echo "Archiving file \"$file\"."
  mv "$file" exported-artifacts/
done
