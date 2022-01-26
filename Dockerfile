ARG BASE_IMAGE=cp.icr.io/cp/appc/ace-server-prod@sha256:f31b9adcfd4a77ba8c62b92c6f34985ef1f2d53e8082f628f170013eaf4c9003
FROM $BASE_IMAGE

# Large number of layers in the ace-server-prod image, squash it to avoid bad performance when using vfs storage driver in builds
COPY --from=0 / /

ARG ACE_VERSION=12.0.2.0
ARG GRADLE_VERSION=7.3.3

LABEL maintainer="Thomas Mattsson <thomas.mattsson@se.ibm.com>"
LABEL io.k8s.description="Platform for building App Connect Enterprise applications into integration server using Maven" \
     io.k8s.display-name="App Connect Enterprise 12.0.2.0" \
     io.openshift.tags="builder,ace,12.0,12.0.2.0" \
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

#WORKDIR /home/aceuser/workspace
ENTRYPOINT []
CMD ["/usr/local/s2i/usage"]
