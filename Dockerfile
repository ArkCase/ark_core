FROM 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest

LABEL ORG="ArkCase LLC" \
      VERSION="1.0" \
      IMAGE_SOURCE=https://github.com/ArkCase/ark_cloudconfig \
      MAINTAINER="ArkCase LLC"
#################
# Build JDK
#################

ARG JAVA_VERSION="1.8.0.322.b06-1.el7_9"

ENV JAVA_HOME=/usr/lib/jvm/java \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

RUN yum update -y && \
    yum -y install java-1.8.0-openjdk-devel-${JAVA_VERSION} unzip && \
    $JAVA_HOME/bin/javac -version
#################
# Build ConfigServer
#################

ARG RESOURCE_PATH="artifacts" 
ARG IMAGEUSERNAME=arkcase
ENV CLOUD_CONFIG_VERSION="2021.03"
WORKDIR /app
RUN    yum update -y  && useradd --create-home --user-group arkcase \
        && mkdir /app/tmp \
        && chown -R ${IMAGEUSERNAME}:${IMAGEUSERNAME} /app \
        && yum -y erase unzip \
        && yum clean all \
        && rm -rf /tmp/*

USER ${IMAGEUSERNAME}
#COPY the application war files
COPY --chown=${IMAGEUSERNAME} ${RESOURCE_PATH}/config-server.jar /app/config-server.jar 
COPY --chown=${IMAGEUSERNAME} ${RESOURCE_PATH}/start.sh /app/start.sh

RUN chmod +x /app/start.sh
EXPOSE 9999

CMD [ "/app/start.sh" ]