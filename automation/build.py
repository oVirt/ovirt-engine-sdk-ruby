#!/usr/bin/python

import datetime
import glob
import lxml.etree
import os
import re
import shutil
import subprocess
import sys


# Settings file that uses the our artifactory server as proxy for all
# repositories:
SETTINGS = """
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
"""


def run_command(args):
    print("Running command %s ..." % args)
    proc = subprocess.Popen(args)
    return proc.wait()


def eval_command(args):
    print("Evaluating command %s ..." % args)
    proc = subprocess.Popen(args, stdout=subprocess.PIPE)
    output, errors = proc.communicate()
    result = proc.wait()
    return result, output


def dec_version(version):
    print("Decrementing version \"%s\"..." % version)
    parts = version.split(".")
    i = len(parts) - 1
    while i >= 0:
        part = parts[i]
        match = re.match(r"^(?P<prefix>.*?)(?P<number>\d+)$", part)
        if match is not None:
            prefix = match.group("prefix")
            number = match.group("number")
            number = int(number)
            if number > 0:
                number -= 1
                parts[i] = "%s%d" % (prefix, number)
                break
        i -= 1
    result = ".".join(parts)
    print("Decremented version is \"%s\"..." % result)
    return result


def extend_path(path):
    print("Adding directory \"%s\" to the path ..." % path)
    paths = os.environ["PATH"].split(":")
    if not path in paths:
        paths.append(path)
    os.environ["PATH"] = ":".join(paths)


def main():
    # Clean the generated artifacts to the output directory:
    print("Cleaning output directory ...")
    artifacts_list = []
    artifacts_path = "exported-artifacts"
    if os.path.exists(artifacts_path):
        shutil.rmtree(artifacts_path)
    os.makedirs(artifacts_path)

    # Extract the version number from the root POM file:
    print("Extracting version from POM ...")
    pom_path = "pom.xml"
    if not os.path.exists(pom_path):
        print("POM file \"%s\" doesn't exist." % pom_path)
        sys.exit(1)
    try:
        pom_doc = lxml.etree.parse(pom_path)
    except lxml.etree.XMLSyntaxError:
        print("Can't parse POM file \"%s\"." % pom_path)
        sys.exit(1)
    version_nodes = pom_doc.xpath(
        "/p:project/p:version",
        namespaces={"p": "http://maven.apache.org/POM/4.0.0"},
    )
    if not version_nodes:
        print("Can't find version in POM file \"%s\"." % pom_path)
        sys.exit(1)
    pom_version = version_nodes[0].text
    print("POM version is \"%s\"." % pom_version)

    # Extract the subject and identifier of the latest commit:
    print("Extracting commit information ...")
    result, commit_info = eval_command([
        "git",
        "log",
        "-1",
        "--oneline",
    ])
    if result != 0:
        print("Extraction of commit info failed with exit code %d." % result)
        sys.exit(1)
    commit_re = re.compile(r"^(?P<id>[0-9a-f]{7}) (?P<title>.*)")
    commit_match = commit_re.match(commit_info)
    if commit_match is None:
        print("Commit info \"%s\" doesn't match format \"%s\"." % (commit_info, commit_re.pattern))
        sys.exit(1)
    commit_id = commit_match.group("id")
    commit_title = commit_match.group("title")
    print("Commit identifier is \"%s\"." % commit_id)
    print("Commit title is \"%s\"." % commit_title)

    # Check if this is a release commit:
    print("Checking if this is a release commit ...")
    is_release = not pom_version.endswith("-SNAPSHOT")
    if is_release:
        print("This is a release commit.")
    else:
        print("This isn't a release commit.")

    # Calculate the SDK version number. This needs to take into account
    # that the number stored in the POM will be the number corresponding
    # to the current release only for release builds. For non release
    # builds the number stored in the POM is the number of the *next*
    # relase, so we need to decrement it, otherwise the version number
    # generated would be newer than the next release, and the upgrade
    # path would be broken.
    print("Calculating SDK version number ...")
    full_version = re.sub(r"-SNAPSHOT$", "", pom_version).lower()
    if not is_release:
        full_version = dec_version(full_version)
    version_re = re.compile(r"^(?P<xyz>\d+\.\d+.\d+)(\.(?P<q>.*))?$")
    version_match = version_re.match(full_version)
    if version_match is None:
        print("SDK version \"%s\" doesn't match format \"%s\"." % (version, version_re.pattern))
        sys.exit(1)
    version_xyz = version_match.group("xyz")
    version_qualifier = version_match.group("q")
    version_suffix = "%sgit%s" % (
        datetime.datetime.now().strftime("%Y%m%d"),
        commit_id,
    )
    if not is_release:
        full_version += ".%s" % version_suffix
    print("SDK version XYZ is \"%s\"." % version_xyz)
    print("SDK version qualifier is \"%s\"." % version_qualifier)
    print("SDK full version is \"%s\"." % full_version)

    # Create the tarball:
    print("Creating tarball ...")
    tar_prefix = "ovirt-engine-sdk-%s" % full_version
    tar_path = "%s.tar.gz" % tar_prefix
    result = run_command([
        "git",
        "archive",
        "--prefix=%s/" % tar_prefix,
        "--output=%s" % tar_path,
        "HEAD",
    ])
    if result != 0:
        print("Tarball creation failed with exit code %d." % result)
        sys.exit(1)
    artifacts_list.append(tar_path)
    print("Tarball file is \"%s\"." % tar_path)

    # When the build runs in mock, it runs as root, and then the
    # executables installed by gems, like the bundle command, are
    # installed to /usr/local/bin, so we need to make sure this is added
    # to the path:
    extend_path("/usr/local/bin")

    # Install bundler. The io-console gem seems to be required by
    # bundler when running in a mock environment in Fedora 24, but it
    # isn't automatically installed.
    print("Installing bundler ...")
    result = run_command([
        "gem",
        "install",
        "io-console",
        "bundler"
    ])
    if result != 0:
        print("Installation of bundler failed with exit code %d." % result)
        sys.exit(1)

    # Build the SDK code generator, run it, and build the gem:
    print("Running Maven build ...")
    settings_path = "settings.xml"
    with open(settings_path, "w") as settings_file:
        settings_file.write(SETTINGS)
    result = run_command([
        "mvn",
        "package",
        "--settings=%s" % settings_path,
        "-Dsdk.version=%s" % full_version,
    ])
    if result != 0:
        print("Maven build failed with exit code %d." % result)
        sys.exit(1)

    # Find the generated gem file and move it to the current directory:
    print("Finding gem file ...")
    gem_path = "sdk/pkg/ovirt-engine-sdk-%s.gem" % full_version
    if not os.path.exists(gem_path):
        print("Gem file \"%s\" doesn't exist." % gem_path)
        sys.exit(1)
    shutil.copy(gem_path, os.getcwd())
    gem_path = os.path.basename(gem_path)
    artifacts_list.append(gem_path)
    print("Gem file is \"%s\"." % gem_path)

    # Find the logs generated by the tests:
    print("Finding test log files ...")
    log_paths = glob.glob("sdk/spec/*.log")
    artifacts_list.extend(log_paths)
    print("Test log files are \"%s\"." % log_paths)

    # Calculate the RPM dist tag:
    print("Find the RPM \"dist\" tag ...")
    result, rpm_dist = eval_command([
        "rpm",
        "--eval",
        "%dist"
    ])
    if result != 0:
        print("Finding the RPM \"dist\" tag failed with exit code %d." % result)
        sys.exit(1)
    rpm_dist = rpm_dist.strip()
    print("RPM \"dist\" is \"%s\"." % rpm_dist)

    # Locate the RPM spec template:
    print("Locating RPM spec template ...")
    spec_template_path = "packaging/spec%s.in" % rpm_dist
    if not os.path.exists(spec_template_path):
        print("RPM spec template \"%s\" doesn't exist." % spec_template_path)
        sys.exit(1)
    print("RPM spec template is \"%s\"." % spec_template_path)

    # Load the RPM spec template:
    print("Loading RPM spec template ...")
    with open(spec_template_path) as spec_fd:
        spec_lines = spec_fd.readlines()
    print("RPM spec loaded")

    # Extract the values of the tags from the RPM spec. The result will
    # be added to a map of tuples, each tuple containing the value of the
    # tag and the index of the line of the spec file.
    print("Extracting RPM tags and globals ...")
    spec_tags = {}
    spec_globals = {}
    tag_re = re.compile(r"^(?P<name>[a-zA-Z0-9_]+)\s*:\s*(?P<value>.*)$")
    global_re = re.compile(r"^%global\s+(?P<name>[a-zA-Z0-9_]+)\s+(?P<value>.*)$")
    for line_index in range(0, len(spec_lines)):
        spec_line = spec_lines[line_index]
        tag_match = tag_re.match(spec_line)
        if tag_match is not None:
            tag_name = tag_match.group("name").lower()
            tag_value = tag_match.group("value")
            spec_tags[tag_name] = (tag_value, line_index)
        global_match = global_re.match(spec_line)
        if global_match is not None:
            global_name = global_match.group("name").lower()
            global_value = global_match.group("value")
            spec_globals[global_name] = (global_value, line_index)

    # Check that the required tags are available:
    print("Checking required RPM tags and globals ...")
    version_tag = spec_tags["version"]
    release_tag = spec_tags["release"]
    source_tag = spec_tags["source"]
    gem_version_global = spec_globals["gem_version"]
    missing = False
    if version_tag is None:
        print("Can't find the RPM version tag.")
        missing = True
    if release_tag is None:
        print("Can't find the RPM release tag.")
        missing = True
    if source_tag is None:
        print("Can't find the RPM source tag.")
        missing = True
    if gem_version_global is None:
        print("Can't find the RPM \"gem_version\" global.")
        missing = True
    if missing:
        sys.exit(1)
    print("RPM version tag is \"%s\"." % version_tag[0])
    print("RPM release tag is \"%s\"." % release_tag[0])
    print("RPM source tag is \"%s\"." % source_tag[0])
    print("RPM \"gem_version\" global is \"%s\"." % gem_version_global[0])

    # Extract the current value of the RPM release tag, discarding the
    # "dist" suffix if it is present:
    print("Extracting current RPM release ...")
    rpm_release = re.sub(r"%\{\?dist\}$", "", release_tag[0])
    print("Current RPM release number is \"%s\"." % rpm_release)

    # Calculate the RPM version and release numbers:
    print("Calculating RPM version and release numbers ...")
    rpm_version = version_xyz
    if version_qualifier is not None:
        rpm_release += ".%s" % version_qualifier
    if not is_release:
        rpm_release += ".%s" % version_suffix
    print("RPM version is \"%s\"." % rpm_version)
    print("RPM release is \"%s\"." % rpm_release)

    # Update the RPM spec lines with the new version and release and
    # write the resulting spec file:
    print("Generating RPM spec file ...")
    spec_lines[version_tag[1]] = "Version: %s\n" % rpm_version
    spec_lines[release_tag[1]] = "Release: %s%%{?dist}\n" % rpm_release
    spec_lines[source_tag[1]] = "Source: %s\n" % gem_path
    spec_lines[gem_version_global[1]] = "%%global gem_version %s\n" % full_version
    spec_path = "rubygem-ovirt-engine-sdk4.spec"
    with open(spec_path, "w") as spec_fd:
        spec_fd.writelines(spec_lines)

    # Build the RPMs:
    cwd = os.getcwd()
    result = run_command([
        "rpmbuild",
        "-ba",
        "--define=_sourcedir %s" % cwd,
        "--define=_srcrpmdir %s" % cwd,
        "--define=_rpmdir %s" % cwd,
        spec_path,
    ])
    if result != 0:
        print("RPM build failed with exit code %d." % result)
        sys.exit(1)
    result, rpm_paths = eval_command([
        "find", ".",
        "-name", "*.rpm",
    ])
    if result != 0:
        print("Finding the RPM files failed with exit code %d." % result)
        sys.exit(1)
    rpm_paths = rpm_paths.split()
    artifacts_list.extend(rpm_paths)
    print("Generated RPM files are \"%s\"." % rpm_paths)

    # Install the RPMs, but only if running as root, which is the case
    # when running inside the mock environment:
    if os.geteuid() == 0:
       install_program = '/usr/bin/dnf'
       if not os.path.exists(install_program):
           install_program = '/usr/bin/yum'
       binary_rpms = [x for x in rpm_paths if not x.endswith("src.rpm")]
       install_command = [
           install_program,
           "-y",
           "install",
       ] + binary_rpms
       result = run_command(install_command)
       if result != 0:
           print("RPM installation failed with exit code %d." % result)
           sys.exit(1)

    # Move all the relevant files to the output directory:
    print("Moving files to the output directory ...")
    for artifact_path in artifacts_list:
        shutil.move(artifact_path, artifacts_path)

if __name__ == "__main__":
    main()
