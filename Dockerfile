#
# Basic Parameters
#
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="2021.03.11"
ARG PKG="cloudconfig"
ARG SRC="https://github.com/ArkCase/acm-config-server.git"

FROM 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest as src

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG PKG
ARG SRC
ARG MAVEN_VER="3.8.6"
ARG MAVEN_SRC="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VER}/binaries/apache-maven-${MAVEN_VER}-bin.tar.gz"

LABEL ORG="ArkCase LLC"
LABEL MAINTAINER="Armedia Devops Team <devops@armedia.com>"
LABEL APP="Cloudconfig"
LABEL VERSION="${VER}"

# Environment variables
ENV VER="${VER}"
ENV SRC="${SRC}"
ENV JAVA_HOME="/usr/lib/jvm/java"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"
ENV MAVEN_VER="3.8.6"
ENV MAVEN_SRC="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VER}/binaries/apache-maven-${MAVEN_VER}-bin.tar.gz"

WORKDIR "/src"

# First, install the JDK
RUN yum update -y && yum -y install java-1.8.0-openjdk-devel git && yum clean all

# Next, the stuff that will be needed for the build
COPY "mvn" "/usr/bin"
ADD "${MAVEN_SRC}" "/"
RUN tar -C / -xzf "/apache-maven-${MAVEN_VER}-bin.tar.gz" && mv -vf "/apache-maven-${MAVEN_VER}" "/mvn"
RUN git clone -b "${VER}" "${SRC}" . && ls -l && mvn clean verify

########################################
# Build ConfigServer                   #
########################################

FROM 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG PKG
ARG APP_UID="997"
ARG APP_GID="${APP_UID}"
ARG APP_USER="${PKG}"
ARG APP_GROUP="${APP_USER}"
ARG BASE_DIR="/app"
ARG DATA_DIR="${BASE_DIR}/data"
ARG TEMP_DIR="${BASE_DIR}/tmp"
ARG HOME_DIR="${BASE_DIR}/home"
ARG RESOURCE_PATH="artifacts" 
ARG SRC
ARG MAIN_CONF="application.yml"

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
ENV EXE_JAR="config-server-${VER}.jar"
ENV MAIN_CONF="${MAIN_CONF}"

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
COPY --from=src "/src/target/${EXE_JAR}" "${BASE_DIR}/${EXE_JAR}"
ADD --chown="${APP_USER}:${APP_GROUP}" "entrypoint" "/entrypoint"

RUN rm -rf /tmp/*
RUN mkdir -p "${TEMP_DIR}" "${DATA_DIR}"
RUN chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}"
RUN chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}"

USER "${APP_USER}"
EXPOSE 9999
VOLUME [ "${DATA_DIR}" ]
ENTRYPOINT [ "/entrypoint" ]
