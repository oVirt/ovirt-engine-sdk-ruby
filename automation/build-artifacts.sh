#!/bin/bash -xe

export JAVA_HOME="${JAVA_HOME:=/usr/lib/jvm/java-21}"

BASE_PATH="${HOME}"
ARTIFACTS_PATH="${BASE_PATH}/exported-artifacts"
ARTIFACTS_PREFIX="ovirt-engine-sdk-"
MVN_PARENT_POM_PATH="${BASE_PATH}/pom.xml"

# Remove created artifacts
cleanup_artifacts() {
  rm -rf $ARTIFACTS_PATH rpmbuild *.tar.gz *.gem *.spec
}

mvn_write_settings() {
  cat >$1 <<EOS
<?xml version="1.0"?>
<settings>
  <mirrors>
    <mirror>
      <id>ovirt-artifactory</id>
      <url>http://artifactory.ovirt.org/artifactory/ovirt-mirror</url>
      <mirrorOf>*</mirrorOf>
    </mirror>

    <mirror>
      <id>maven-central</id>
      <url>https://repo.maven.apache.org/maven2</url>
      <mirrorOf>*</mirrorOf>
    </mirror>
  </mirrors>
</settings>
EOS
}

git_commit() {
  local commit=$(git log -1 --oneline)
  (echo $commit | grep -Eq "^$1$") && echo $commit || return 1
}

# Decrement version number
# 4.4.1 => 4.4.0
# 4.4.0 => 4.3.0
# 4.4.1.beta2 => 4.4.1.beta1
dec_version() {
  local IFS='.'
  read -ra parts <<< "$1"

  for (( i=$(( ${#parts[@]}-1 )); i>=0; i-- )); do
    read -r prefix number < <(sed -r 's/([[:alpha:]]*)([[:digit:]])/\1.\2/p' <<< ${parts[i]})
    [[ $number -gt 0 ]] && { parts[i]="${prefix}$(( ${number}-1 ))"; break; }
  done

  echo "${parts[*]}"
}

# Prepare for new build: remove several artifacts, write mvn settings and create empty artifacts folder
cleanup_artifacts
mkdir $ARTIFACTS_PATH

# Download and install mvn dependencies
mvn help:evaluate -Dexpression=project.version

# Get the POM version
POM_VERSION=$(mvn help:evaluate -Dexpression=project.version 2>/dev/null | grep -v "^\[")
IFS='-' read -r VERSION SNAPSHOT <<< "$POM_VERSION"
# -------------------------

# If not a release, decrement version
[[ -n $SNAPSHOT ]] && VERSION=$( dec_version $VERSION )

# Get commit id and title from git if they match the regexp
echo "Fetching the commit info ..."

COMMIT_REGEXP="([0-9a-f]{7})\\s(.*)"
COMMIT=$(git_commit $COMMIT_REGEXP) || { echo "Commit info does not match right format '$COMMIT_REGEXP'"; exit 1; }
read -r COMMIT_ID COMMIT_TITLE < <(sed -r "s/${COMMIT_REGEXP}/\1 \2/p" <<< ${COMMIT})

echo "Commit ID: ${COMMIT_ID} | Commit Title: ${COMMIT_TITLE}"
# -------------------------

# Calculating SDK version number
echo "Calculation SDK version number ..."

VERSION_REGEXP="([0-9]+\.[0-9]+\.[0-9]+)(\.(.*))?"
(echo $VERSION | grep -Eq "^${VERSION_REGEXP}$") || { echo "SDK version '${VERSION}' does not match right format '$VERSION_REGEXP'"; exit 1; }
read -r VERSION_XYZ VERSION_QUALIFIER < <(sed -r "s/${VERSION_REGEXP}/\1 \2/p" <<< $VERSION)
VERSION_SUFFIX="$(date +%04Y%02m%02d)git${COMMIT_ID}"

[[ -n $SNAPSHOT ]] && VERSION="${VERSION}.${VERSION_SUFFIX}"

echo "SDK version XYZ is ${VERSION_XYZ}"
echo "SDK qualifier is ${VERSION_QUALIFIER}"
echo "SDK full version is ${VERSION}"
# -------------------------

# Creating tarball
echo "Creating tarball ..."

TAR_NAME="${ARTIFACTS_PREFIX}${VERSION}.tar.gz"
TAR_PATH="${BASE_PATH}/${TAR_NAME}"
git archive --format=tar --prefix="${ARTIFACTS_PREFIX}${VERSION}/" HEAD | gzip -9 > $TAR_PATH
[[ -s $TAR_PATH ]] || { echo "Error generating tarball file '${TAR_PATH}"; exit $?; }

echo "Tarball file is ${TAR_PATH}.tar.gz"
# -------------------------

# Building the SDK code generator, run it and build the gem
export PATH="${PATH}:/usr/local/bin"

echo "Running Maven build ..."
mvn package -Dsdk.version=${VERSION} -P!bundler,rpm
# ---

echo "Finding built gem"
GEM_NAME="${ARTIFACTS_PREFIX}${VERSION}.gem"
GEM_PATH="sdk/pkg/${GEM_NAME}"
[[ -s $GEM_PATH ]] && cp $GEM_PATH ${BASE_PATH} || { echo "Gem file '${GEM_PATH} does not exist"; exit $?; }

echo "Gem file is ${GEM_PATH}"
# -------------------------

# rpmbuild
echo "Generating the spec file"
SPEC_TPL_PATH="${BASE_PATH}/packaging/spec.in"
RPM_RELEASE_REGEXP="^(Release:\\s*)(.*)(%\{\?dist\})$"
RPM_RELEASE=$(sed -rn "s/$RPM_RELEASE_REGEXP/\2/p" $SPEC_TPL_PATH)

[[ -n $VERSION_QUALIFIER ]] && RPM_RELEASE="${RPM_RELEASE}.${VERSION_QUALIFIER}"
[[ -n $SNAPSHOT ]] && RPM_RELEASE="${RPM_RELEASE}.${VERSION_SUFFIX}"

SPEC_PATH="${BASE_PATH}/rubygem-ovirt-engine-sdk4.spec"
sed \
  -re "s/@VERSION@/${VERSION_XYZ}/g" \
  -re "s/@GEM_VERSION@/${VERSION}/g" \
  -re "s/${RPM_RELEASE_REGEXP}/\1${RPM_RELEASE}\3/" \
  -re "s/@GEM_SOURCE@/${GEM_NAME}/g" \
  < ${SPEC_TPL_PATH} \
  > ${SPEC_PATH}
# ---

echo "Generating the rpms"
rpmbuild \
  -ba \
  --define "_sourcedir $PWD" \
  --define "_srcrpmdir $PWD" \
  --define "_rpmdir $PWD" \
  ${SPEC_PATH}
# ---

echo "Installing rpm"
ALL_RPMS=$(find $BASE_PATH -iname \*rpm | tr '\n' ' ')
RPMS_NO_SRC=$(find $BASE_PATH -iname \*rpm | grep -v 'src\.rpm' | tr '\n' ' ')
(/usr/bin/dnf -y install $RPMS_NO_SRC) || { echo "RPM installation failed with exit code $?"; exit 1; }
# -------------------------

# Moving artifacts
echo "Move rpms to ${ARTIFACTS_PATH}"
mv $ALL_RPMS $ARTIFACTS_PATH

echo "Move tarball to ${ARTIFACTS_PATH}"
mv $TAR_PATH ${ARTIFACTS_PATH} || { echo "Error generating tarball file '${TAR_PATH}"; exit $?; }

echo "Move gem to ${ARTIFACTS_PATH}"
mv ${BASE_PATH}/${GEM_NAME} $ARTIFACTS_PATH

echo "Find test log files and move"
mv sdk/spec/*.log $ARTIFACTS_PATH
# -------------------------
