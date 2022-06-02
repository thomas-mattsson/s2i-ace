# For ACE Versions,see: https://www.ibm.com/docs/en/app-connect/containers_cd?topic=obtaining-app-connect-enterprise-server-image-from-cloud-container-registry 
# Use ACE 12.0.4.0-r2
ARG ACE_BASE_IMAGE=cp.icr.io/cp/appc/ace-server-prod@sha256:7eb8483de45c1634d09e24521b9d2f89a9e4d0c9b89a1a5d52cc4fd37a091234
ARG BASE_IMAGE=registry.access.redhat.com/ubi8/ubi-minimal@sha256:9a81cce19ae2a962269d4a7fecd38aec60b852118ad798a265c3f6c4be0df610
FROM $ACE_BASE_IMAGE as ace

# Large number of layers in the ace-server-prod image, squash it to avoid bad performance when using vfs storage driver in builds
FROM $BASE_IMAGE
COPY --from=ace / /
# Need to recreate env vars due to squash wa above
ENV BASH_ENV=/usr/local/bin/ace_env.sh
ENV LOG_FORMAT=basic
ENV MQ_OVERRIDE_DATA_PATH=/var/mqm/data
ENV MQ_OVERRIDE_INSTALLATION_NAME=Installation1
ENV MQ_USER_NAME=mqm
ENV AMQ_DIAGNOSTIC_MSG_SEVERITY=1
ENV AMQ_ADDITIONAL_JSON_LOG=1
ENV MQCERTLABL=aceclient
ENV PRODNAME=AppConnectEnterprise
ENV COMPNAME=IntegrationServer

ARG ACE_VERSION=12.0.4.0
ARG GRADLE_VERSION=7.4.2

LABEL maintainer="Thomas Mattsson <thomas.mattsson@se.ibm.com>"
LABEL io.k8s.description="Platform for building App Connect Enterprise applications into integration server using Gradle" \
     io.k8s.display-name="App Connect Enterprise 12.0.4.0" \
     io.openshift.tags="builder,ace,12.0,12.0.4.0" \
     io.openshift.s2i.scripts-url=image:///usr/local/s2i

USER root

# Download and install Gradle
ENV GRADLE_ZIP gradle-${GRADLE_VERSION}-bin.zip
RUN \
    cd /usr/local && \
    curl -L https://services.gradle.org/distributions/${GRADLE_ZIP} -o ${GRADLE_ZIP} && \
    unzip ${GRADLE_ZIP} && \
    rm ${GRADLE_ZIP}

# Export some environment variables
ENV GRADLE_HOME=/usr/local/gradle-${GRADLE_VERSION}
ENV PATH=$PATH:$GRADLE_HOME/bin
# JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

USER aceuser

# To support local dependencies in maven
ENV MQSI_BASE_FILEPATH=/opt/ibm/ace-12

COPY ./s2i/bin/ /usr/local/s2i

CMD ["/usr/local/s2i/usage"]
