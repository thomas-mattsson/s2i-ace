# ACE S2I builder image

First of all look at the following repos for great examples on creating containerized ACE:

<https://github.com/ot4i/ace-demo-pipeline>
<https://github.com/ot4i/ace-docker>

The main purpose for this image is to allow for building ACE projects as part of Openshift pipelines. Maven or Gradle is used to facilitate the build of the project and either a `pom.xml` or a `build.gradle` file needs to be present.
Besides the image itself, a tekton task is provided to support a build from git to an integration server image.

For more information around S2I see: <https://github.com/openshift/source-to-image>

The ACE S2I builder is only meant as a build image and not actually use it as a runtime image as can be read about here:
<https://github.com/openshift/source-to-image/blob/master/docs/runtime_image.md>

Execution from the command line would for example be:
`s2i build -c -e LICENSE=accept . s2i-ace:latest test-s2i --runtime-image=cp.icr.io/cp/appc/ace-server-prod@sha256:8598eef24c097e467bfa33499e62fe0dcfbfd817d877bd2347c857870b47b8fa --runtime-artifact=/tmp:initial-config/bars --assemble-runtime-user aceuser`

For Openshift pipelines however, `--runtime-image` can not be used since s2i is only used for generating the dockerfile. Instead a task is provided here to package the build artifacts properly.

## Building the image

Image can be built locally with `make build`. Unit tests can be executed with `make test`. Podman is being used for the build, and it's necessery to login to the IBM entitlement container registry.

A [build config](buildconfig/buildconfig.yaml) has been provided to build the image in an Openshift cluster. A `ibm-entitlement-key` secret is required to build the ACE base image following instructions here: <https://www.ibm.com/docs/en/cloud-paks/cp-integration/2022.4?topic=ayekoi-applying-your-entitlement-key-using-ui-online-installation>

## Gradle/Maven

Image contains both Gradle and Maven supporting either of them for building the ACE project. Additionally the [ACE Maven plugin](https://github.com/ot4i/ace-maven-plugin) and [ACE Gradle plugin](https://github.com/thomas-mattsson/ace-gradle-plugin) is added to the image as they are currently not published in any public maven repository.

The image will look for a `build.gradle` or a `pom.xml` file in the root of the build directory. If both are found, `build.gradle` will be prioritized.

### Gradle

In case of a `build.gradle` file being present in the build directory, the image will execute gradle without any explicit tasks. Adding default tasks to the `build.gradle` file would be necessary. Any bar files that would be existed in the build directory would be copied to the final image.

<https://github.com/thomas-mattsson/ace-gradle-plugin> is included in the image making it easy to build and test ACE projects. For an example project see here: <https://github.com/thomas-mattsson/ace-gradle-plugin/tree/main/sample/ace-hello-world>.

### Maven

In case of a `pom.xml` file being present in the build directory, Maven will be used to facilitate the build by calling `mvn package`.

Image is currently using the version at <https://github.com/ChrWeissDe/ace-maven-plugin> instead of <https://github.com/ot4i/ace-maven-plugin> that introduces support for ACE 12 test projects allowing JUnit tests to be executed as part of the build process.

More information on how that can be used in a CI/CD context can be read about here:
<https://community.ibm.com/community/user/integration/viewdocument/ibm-ace-v11-continuous-integration>

Besides the pom.xml files needed for the ace projects, a pom.xml is also needed in the root to include all the projects that should be included in the integration server build. For example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
 xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
 <modelVersion>4.0.0</modelVersion>
 <groupId>myGroupId</groupId>
 <artifactId>myIntegrationServerId</artifactId>
 <version>0.0.1-SNAPSHOT</version>
 <packaging>pom</packaging>
 <name>myIntegrationServerName</name>
 <modules>
  <module>ACE_project_1</module>
  <module>ACE_project_2</module>
 </modules>
  <properties>
    <maven.deploy.skip>true</maven.deploy.skip>
  </properties>
</project>
```

## Openshift Pipelines/Tekton

### Task for building using the ACE S2I image

Add [tekton/s2i-ace-task.yml](tekton/s2i-ace-task.yml) as a Openshift Pipeline task. Make sure to update the namespace name to match your Openshift project.

Task also allows to provide a different runtime image instead of the build image (which would be larger due to the added build files) by setting the `RUNTIME_IMAGE` parameter. See documentation for the different parameters in the task.

There is also a [tekton/s2i-ace-overlay-task.yml](tekton/s2i-ace-overlay-task.yml) task that does the same thing, but is using the buildah `overlay2` storage driver instead of `vfs`. Task is also setup to use a PVC with the name `s2i-ace-varlibcontainers-pvc` that would need to be created with a block storage class. This will be used for storing the layers built by `buildah` and will speed up the pipelines considerably. Note however that the `pipeline` service account would need to be allowed to run as privileged to use any other storage driver than `vfs`.
