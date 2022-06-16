FROM 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest

#
# Basic Parameters
#
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="2021.03"
ARG PKG="cloudconfig"
ARG APP_UID="997"
ARG APP_GID="${APP_UID}"
ARG APP_USER="${PKG}"
ARG APP_GROUP="${APP_USER}"
ARG BASE_DIR="/app"
ARG DATA_DIR="${BASE_DIR}/data"
ARG TEMP_DIR="${BASE_DIR}/tmp"
ARG HOME_DIR="${BASE_DIR}/home"
ARG RESOURCE_PATH="artifacts" 
ARG JAR_SRC="https://github.com/ArkCase/acm-config-server/releases/download/${VER}/config-server-${VER}.jar"
ARG MAIN_CONFIG="application.yml"

LABEL ORG="ArkCase LLC"
LABEL MAINTAINER="Armedia Devops Team <devops@armedia.com>"
LABEL APP="Cloudconfig"
LABEL VERSION="${VER}"

# Environment variables
ENV APP_UID="${APP_UID}"
ENV APP_GID="${APP_GID}"
ENV APP_USER="${APP_USER}"
ENV APP_GROUP="${APP_GROUP}"
ENV JAVA_HOME="/usr/lib/jvm/java"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV BASE_DIR="${BASE_DIR}"
ENV DATA_DIR="${DATA_DIR}"
ENV TEMP_DIR="${TEMP_DIR}"
ENV HOME_DIR="${HOME_DIR}"
ENV EXE_JAR="${BASE_DIR}/config-server-${VER}.jar"
ENV MAIN_CONFIG="${MAIN_CONFIG}"

WORKDIR "${BASE_DIR}"

#################
# First, install the JDK
#################

RUN yum update -y && yum -y install java-1.8.0-openjdk-devel git && yum clean all

#################
# Build ConfigServer
#################

#
# Create the requisite user and group
#
RUN groupadd --system --gid "${APP_GID}" "${APP_GROUP}"
RUN useradd  --system --uid "${APP_UID}" --gid "${APP_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}"

#
# COPY the application war files
#
ADD "${JAR_SRC}" "${EXE_JAR}"

RUN rm -rf /tmp/*
RUN mkdir -p "${TEMP_DIR}" "${DATA_DIR}"
RUN chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}"
RUN chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}"

USER "${APP_USER}"
EXPOSE 9999
VOLUME [ "${DATA_DIR}" ]
ENTRYPOINT [ "/usr/bin/java", "-jar", "${EXE_JAR}", "--spring.config.location=file://${DATA_DIR}/${MAIN_CONFIG}" ]
