# ACE S2I builder image

The main purpose for this image is to allow for building ACE projects as part of Openshift pipelines.
Besides the image itself, a tekton task is provided to support a build from git to an integration server image.

The ACE S2I builder is only meant as a build image and not actually use it as a runtime image as can be read about here:
<https://github.com/openshift/source-to-image/blob/master/docs/runtime_image.md>

Execution from the command line would for example be:
`s2i build -c -e LICENSE=accept . s2i-ace-maven:latest test-s2i --runtime-image=cp.icr.io/cp/appc/ace-server-prod@sha256:8598eef24c097e467bfa33499e62fe0dcfbfd817d877bd2347c857870b47b8fa --runtime-artifact=/tmp:initial-config/bars --assemble-runtime-user aceuser`

For Openshift pipelines however, `--runtime-image` can not be used since s2i is only used for generating the dockerfile. Instead a task is provided here to package the build artifacts properly.

## Maven

Maven is used for managing the build of the ACE project. The [ace-maven-plugin](https://github.com/ot4i/ace-maven-plugin) is also included into this image. Image is currently using the version at https://github.com/thomas-mattsson/ace-maven-plugin that introduces support for ACE 12 test projects allowing JUnit tests to be executed as part of the build process.

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

### Pipeline for building this image itself

Add [tekton/build-s2i-ace-maven-pipeline.yml](tekton/build-s2i-ace-maven-pipeline.yml) as a Openshift Pipeline. Make sure to update the namespace name to match your Openshift project.

Pipeline takes a git source as input (this git repo) and an image output. Use `image-registry.openshift-image-registry.svc:5000/mvp/s2i-ace-maven:11.0.0.12` as image URL for using the internal image registry and using the tag with the currently matching version. If using other image repository or tag, make sure to update the task below to match.

### Task for building an integration server

Add [tekton/s2i-ace-maven-task.yml](tekton/s2i-ace-maven-task.yml) as a Openshift Pipeline task. Make sure to update the namespace name to match your Openshift project.

Task is also setup to use a PVC with the name `s2i-ace-maven-varlibcontainers-pvc` that would need to be created with a block storage class. This will be used for storing the s2i container and the resulting integration servers.

### Deploying the integration server

There are several tasks for deploying integration servers based on template files.

#### Deploying single integration server based on template and parameters

[tekton/ace-integration-server-deployment-task.yml](tekton/ace-integration-server-deployment-task.yml)

#### Deploying multiple integration servers based on template and parameter files

[tekton/ace-deploy-integration-servers-task.yml](tekton/ace-deploy-integration-servers-task.yml)

#### Deploying configurations based on template

[tekton/ace-configuration-policy-project-deployment-task.yml](tekton/ace-configuration-policy-project-deployment-task.yml)
[tekton/ace-configuration-serverconf-deployment-task.yml](tekton/ace-configuration-serverconf-deployment-task.yml)

#### Creating the pipeline

Pipeline at [tekton/build-and-deploy-pipeline.yml](tekton/build-and-deploy-pipeline.yml) is an example on how to have an ingration with github, building the integration server with new tag for each build, also tagging with `latest`, and deploying to a dev environment using templates.

## Reference: Creating a basic S2I builder image  

### Files and Directories  

| File                   | Required? | Description                                                  |
|------------------------|-----------|--------------------------------------------------------------|
| Dockerfile             | Yes       | Defines the base builder image                               |
| s2i/bin/assemble       | Yes       | Script that builds the application                           |
| s2i/bin/usage          | No        | Script that prints the usage of the builder                  |
| s2i/bin/run            | Yes       | Script that runs the application                             |
| s2i/bin/save-artifacts | No        | Script for incremental builds that saves the built artifacts |
| test/run               | No        | Test script for the builder image                            |
| test/test-app          | Yes       | Test application source code                                 |

#### Dockerfile

Create a *Dockerfile* that installs all of the necessary tools and libraries that are needed to build and run our application.  This file will also handle copying the s2i scripts into the created image.

#### S2I scripts

##### assemble

Create an *assemble* script that will build our application, e.g.:

- build python modules
- bundle install ruby gems
- setup application specific configuration

The script can also specify a way to restore any saved artifacts from the previous image.

##### run

Create a *run* script that will start the application.

##### save-artifacts (optional)

Create a *save-artifacts* script which allows a new build to reuse content from a previous version of the application image.

##### usage (optional)

Create a *usage* script that will print out instructions on how to use the image.

##### Make the scripts executable

Make sure that all of the scripts are executable by running *chmod +x s2i/bin/**

#### Create the builder image

The following command will create a builder image named s2i-ace-maven based on the Dockerfile that was created previously.

```
docker build -t s2i-ace-maven .
```

The builder image can also be created by using the *make* command since a *Makefile* is included.

Once the image has finished building, the command *s2i usage s2i-ace-maven* will print out the help info that was defined in the *usage* script.

#### Testing the builder image

The builder image can be tested using the following commands:

```
docker build -t s2i-ace-maven-candidate .
IMAGE_NAME=s2i-ace-maven-candidate test/run
```

The builder image can also be tested by using the *make test* command since a *Makefile* is included.

#### Creating the application image

The application image combines the builder image with your applications source code, which is served using whatever application is installed via the *Dockerfile*, compiled using the *assemble* script, and run using the *run* script.
The following command will create the application image:

```
s2i build test/test-app s2i-ace-maven s2i-ace-maven-app
---> Building and installing application from source...
```

Using the logic defined in the *assemble* script, s2i will now create an application image using the builder image as a base and including the source code from the test/test-app directory.

#### Running the application image

Running the application image is as simple as invoking the docker run command:

```
docker run -d -p 8080:8080 s2i-ace-maven-app
```

The application, which consists of a simple static web page, should now be accessible at  [http://localhost:8080](http://localhost:8080).

#### Using the saved artifacts script

Rebuilding the application using the saved artifacts can be accomplished using the following command:

```
s2i build --incremental=true test/test-app nginx-centos7 nginx-app
---> Restoring build artifacts...
---> Building and installing application from source...
```

This will run the *save-artifacts* script which includes the custom code to backup the currently running application source, rebuild the application image, and then re-deploy the previously saved source using the *assemble* script.
