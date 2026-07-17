#!/bin/bash -xe

export JAVA_HOME="${JAVA_HOME:=/usr/lib/jvm/java-21}"

ARTIFACTS_PATH="${PWD}/exported-artifacts"
ARTIFACTS_PREFIX="ovirt-engine-sdk-"

mkdir -p "${ARTIFACTS_PATH}"

# Determine the RPM version:
# - For tagged builds, RPM_VERSION is set in the GitHub Actions environment.
# - For non-tagged builds, derive from the Maven POM version by stripping
#   the -SNAPSHOT suffix.
if [[ -z "${RPM_VERSION}" ]]; then
    POM_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
    RPM_VERSION="${POM_VERSION%-SNAPSHOT}"
fi

PACKAGE_RPM_RELEASE="${PACKAGE_RPM_RELEASE:-0.master}"

GEM_VERSION="${RPM_VERSION}"
GEM_NAME="${ARTIFACTS_PREFIX}${GEM_VERSION}.gem"

# Build the gem via Maven
mvn package -Dsdk.version="${GEM_VERSION}" -P!bundler,rpm

GEM_PATH="sdk/pkg/${GEM_NAME}"
[[ -s "${GEM_PATH}" ]] || { echo "Gem file '${GEM_PATH}' does not exist"; exit 1; }
cp "${GEM_PATH}" .

# Generate RPM spec from template
SPEC_PATH="${PWD}/rubygem-ovirt-engine-sdk4.spec"
sed \
    -e "s/@VERSION@/${RPM_VERSION}/g" \
    -e "s/@GEM_VERSION@/${GEM_VERSION}/g" \
    -e "s/@PACKAGE_RPM_RELEASE@/${PACKAGE_RPM_RELEASE}/g" \
    -e "s/@GEM_SOURCE@/${GEM_NAME}/g" \
    packaging/spec.in > "${SPEC_PATH}"

# Build RPMs
RPMBUILD_ARGS=(
    -ba
    --define "_sourcedir ${PWD}"
    --define "_srcrpmdir ${PWD}"
    --define "_rpmdir ${PWD}"
)
if [[ -n "${RELEASE_SUFFIX}" ]]; then
    RPMBUILD_ARGS+=(--define "release_suffix ${RELEASE_SUFFIX}")
fi

rpmbuild "${RPMBUILD_ARGS[@]}" "${SPEC_PATH}"

# Collect artifacts
find "${PWD}" -maxdepth 2 -name "*.rpm" -exec mv {} "${ARTIFACTS_PATH}/" \;
cp "${GEM_NAME}" "${ARTIFACTS_PATH}/"
