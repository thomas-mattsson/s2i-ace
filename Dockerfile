# For ACE Versions,see: https://www.ibm.com/docs/en/app-connect/containers_cd?topic=obtaining-app-connect-enterprise-server-image-from-cloud-container-registry 
# Use ACE 12.0.5.0-r3
ARG ACE_BASE_IMAGE=cp.icr.io/cp/appc/ace-server-prod@sha256:7eb8483de45c1634d09e24521b9d2f89a9e4d0c9b89a1a5d52cc4fd37a091234

# Getting the ACE maven plugin source
FROM alpine/git as ace-maven-plugin
WORKDIR /app
# Make sure git clone is not being cached if there's been changes (https://stackoverflow.com/questions/36996046/how-to-prevent-dockerfile-caching-git-clone)
#ADD https://api.github.com/repos/ChrWeissDe/ace-maven-plugin/git/refs/heads/main version.json
# Using a fixed commit until there's a tagged release
RUN git clone -b main https://github.com/ChrWeissDe/ace-maven-plugin.git ace-maven-plugin && \
    cd ace-maven-plugin && \
    git reset b488977 --hard

# Getting the ACE gradle plugin source
FROM alpine/git as ace-gradle-plugin
WORKDIR /app
# Make sure git clone is not being cached if there's been changes (https://stackoverflow.com/questions/36996046/how-to-prevent-dockerfile-caching-git-clone)
ADD https://api.github.com/repos/thomas-mattsson/ace-gradle-plugin/git/refs/heads/main version.json
RUN git clone -b main https://github.com/thomas-mattsson/ace-gradle-plugin.git ace-gradle-plugin

FROM $ACE_BASE_IMAGE as ace

LABEL maintainer="Thomas Mattsson <thomas.mattsson@se.ibm.com>"
LABEL io.k8s.description="Platform for building App Connect Enterprise applications into integration server using Gradle" \
     io.k8s.display-name="IBM App Connect Enterprise 12.0.5.0-r3" \
     io.openshift.tags="ace,12.0,12.0.5.0-r3" \
     io.openshift.s2i.scripts-url=image:///usr/local/s2i

USER root

ARG GRADLE_VERSION=7.5.1

# Export some environment variables
ENV GRADLE_HOME=/usr/local/gradle-${GRADLE_VERSION}
ENV PATH=$PATH:$GRADLE_HOME/bin

# Download and install Gradle
ENV GRADLE_ZIP gradle-${GRADLE_VERSION}-bin.zip
RUN \
    cd /usr/local && \
    curl -L https://services.gradle.org/distributions/${GRADLE_ZIP} -o ${GRADLE_ZIP} && \
    unzip ${GRADLE_ZIP} && \
    rm ${GRADLE_ZIP}

RUN microdnf update \
 && microdnf install --nodocs \
    maven \
 && microdnf clean all \
 && rm -rf /var/cache/yum

USER aceuser

# Building the ace maven plugin
COPY --from=ace-maven-plugin --chown=aceuser:0 /app/ace-maven-plugin /tmp/ace-maven-plugin
COPY --chown=aceuser:0 ./settings.xml /home/aceuser/.m2/

# TODO: Replace -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn with --no-transfer-progress
# when on a later version in maven package
RUN mvn -f /tmp/ace-maven-plugin/ace-maven-plugin/pom.xml versions:set -DremoveSnapshot -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn -B && \
    mvn -f /tmp/ace-maven-plugin/ace-maven-plugin/pom.xml -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn -B package && \
    mvn install:install-file -Dfile=/tmp/ace-maven-plugin/ace-maven-plugin/target/ace-maven-plugin-12.0.3.jar -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn -DpomFile=/tmp/ace-maven-plugin/ace-maven-plugin/pom.xml -DcreateChecksum=true -B && \
    rm -rf /tmp/ace-maven-plugin

# Building the ace gradle plugin
COPY --from=ace-gradle-plugin --chown=aceuser:0 /app/ace-gradle-plugin /tmp/ace-gradle-plugin
COPY --chown=aceuser:0 ./init.gradle /home/aceuser/.gradle/

RUN gradle --no-daemon -g /home/aceuser/.gradle -p /tmp/ace-gradle-plugin publish && \
    chown -R aceuser:0 /home/aceuser/.gradle && \
    chmod -R g=u /home/aceuser/.gradle

# To support local dependencies in maven
ENV MQSI_BASE_FILEPATH=/opt/ibm/ace-12

COPY ./s2i/bin/ /usr/local/s2i

CMD ["/usr/local/s2i/usage"]
