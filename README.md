# oVirt Ruby SDK

## Introduction

The oVirt Ruby SDK is a Ruby gem that simplyfies access to the oVirt
Engine API.

## Building

Most of the source code of the Ruby SDK is automatically generated from
the API model.

The code generator is a Java program that resides in the `generator`
directory.  This Java program will get the API model and the metamodel
artifacts from the available Maven repositories. To build and run it use
the following commands:

```
$ git clone git://gerrit.ovirt.org/ovirt-engine-sdk-ruby
$ cd ovirt-engine-sdk-ruby
$ mvn package
```

This will build the code generator, run it to generate the SDK for the
version of the API that corresponds to the branch of the SDK that you
are using, and build the `.gem` file.

If you need to generate it for a different version of the API then you
can use the `model.version` property. For example, if you need to
generate the SDK for version `4.1.0` of the SDK you can use this
command:

```
$ mvn package -Dmodel.version=4.1.0
```

The generated `.gem` file will be located in the `sdk` directory:

```
$ ls sdk/*.gem
sdk/ovirt-engine-sdk-4.0.0.alpha0.gem
```
