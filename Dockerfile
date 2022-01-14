ARG BASE_IMAGE=cp.icr.io/cp/appc/ace-server-prod@sha256:f31b9adcfd4a77ba8c62b92c6f34985ef1f2d53e8082f628f170013eaf4c9003
FROM $BASE_IMAGE

ARG ACE_VERSION=12.0.2.0

LABEL maintainer="Thomas Mattsson <thomas.mattsson@se.ibm.com>"
LABEL io.k8s.description="Platform for building App Connect Enterprise applications into integration server using Maven" \
     io.k8s.display-name="App Connect Enterprise 12.0.2.0" \
     io.openshift.tags="builder,ace,12.0,12.0.2.0" \
     io.openshift.s2i.scripts-url=image:///usr/local/s2i

# To support local dependencies in maven
ENV MQSI_BASE_FILEPATH=/opt/ibm/ace-12

# Copying mq runtime
COPY --from=ibmcom/mq:9.2.2.0-r1 --chown=aceuser:0 /opt/mqm /opt/mqm

COPY ./s2i/bin/ /usr/local/s2i

#WORKDIR /home/aceuser/workspace

CMD ["/usr/local/s2i/usage"]
