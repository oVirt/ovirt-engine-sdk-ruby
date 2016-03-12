#!/bin/bash -ex

# Name and version of the package:
gem_version="${gem_version:=4.0.0.alpha11}"
gem_url="${gem_url:=https://rubygems.org/downloads/ovirt-engine-sdk-${gem_version}.gem}"
rpm_version="${rpm_version:=4.0.0}"
rpm_dist="${rpm_dist:=$(rpm --eval '%dist')}"
rpm_release="${rpm_release:=0.0.alpha11${rpm_dist}}"

# Generate the .spec file from the template for the distribution where the
# build process is running:
spec_template="spec${rpm_dist}.in"
spec_file="rubygem-ovirt-engine-sdk.spec"
sed \
  -e "s|@GEM_VERSION@|${gem_version}|g" \
  -e "s|@GEM_URL@|${gem_url}|g" \
  -e "s|@RPM_VERSION@|${rpm_version}|g" \
  -e "s|@RPM_RELEASE@|${rpm_release}|g" \
  < "${spec_template}" \
  > "${spec_file}" \

# Download the sources:
spectool \
  --get-files \
  "${spec_file}"

# Build the source and binary .rpm files:
rpmbuild \
  -bb \
  --define="_sourcedir ${PWD}" \
  --define="_rpmdir ${PWD}" \
  "${spec_file}"
