# Getting the ACE maven plugin source
FROM alpine/git
WORKDIR /app
RUN git clone https://github.com/ot4i/ace-maven-plugin.git \
  && rm -rf /app/ace-maven-plugin/ace-maven-plugin/{target,bin}

FROM ubuntu:16.04

ARG ACE_VERSION=12.0.1.0

LABEL maintainer="Thomas Mattsson <thomas.mattsson@se.ibm.com>"
LABEL io.k8s.description="Platform for building App Connect Enterprise applications into integration server using Maven" \
     io.k8s.display-name="App Connect Enterprise 12.0.1.0" \
     io.openshift.tags="builder,ace,12.0,12.0.1.0" \
     io.openshift.s2i.scripts-url=image:///usr/local/s2i

# Prevent errors about having no terminal when using apt-get
ENV DEBIAN_FRONTEND noninteractive

# mqsicreatebar prereqs; need to run "Xvfb -ac :99 &" and "export DISPLAY=:99"
# install jdk and maven for build support
RUN apt-get update && apt-get -y install libgtk2.0-0 libxtst6 xvfb default-jdk maven curl

# Install ACE and accept the license
RUN mkdir /opt/ibm && echo Downloading package http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/integration/${ACE_VERSION}-ACE-LINUX64-DEVELOPER.tar.gz && \
    curl -sL http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/integration/${ACE_VERSION}-ACE-LINUX64-DEVELOPER.tar.gz | tar xvz --directory /opt/ibm

# To use a downloaded copy instead of downloading it, use the below part
#ADD ${ACE_VERSION}-ACE-LINUX64-DEVELOPER.tar.gz /opt/ibm

RUN mv /opt/ibm/ace-${ACE_VERSION} /opt/ibm/ace-11 \
  && /opt/ibm/ace-11/ace make registry global accept license deferred \
  && useradd --uid 1001 --create-home --home-dir /home/aceuser --shell /bin/bash -g 0 -G mqbrkrs aceuser \
  && mkdir -p /home/aceuser/.swt/lib/linux/x86_64/ \
  && ln -s /usr/lib/jni/libswt-* /home/aceuser/.swt/lib/linux/x86_64/

USER aceuser

# Building the ace maven plugin
COPY --from=0 --chown=aceuser:0 /app/ace-maven-plugin /home/aceuser/ace-maven-plugin
COPY --chown=aceuser:0 ./settings.xml /home/aceuser/.m2/

RUN mkdir /home/aceuser/workspace \
  && mvn -f /home/aceuser/ace-maven-plugin/ace-maven-plugin/pom.xml versions:set -DremoveSnapshot -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn -B \
  && mvn -f /home/aceuser/ace-maven-plugin/ace-maven-plugin/pom.xml -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn -B package \
  && mvn install:install-file -Dfile=/home/aceuser/ace-maven-plugin/ace-maven-plugin/target/ace-maven-plugin-11.39.jar -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn -DpomFile=/home/aceuser/ace-maven-plugin/ace-maven-plugin/pom.xml -DcreateChecksum=true -B

COPY ./s2i/bin/ /usr/local/s2i

WORKDIR /home/aceuser/workspace

CMD ["/usr/local/s2i/usage"]
