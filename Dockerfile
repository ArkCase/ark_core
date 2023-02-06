###########################################################################################################
#
# How to build:
#
# docker build -t 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_cloudconfig:latest .
# docker push 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_cloudconfig:latest
#
# How to run: (Helm)
#
# helm repo add arkcase https://arkcase.github.io/ark_helm_charts/
# helm install ark_cloudconfig arkcase/ark_cloudconfig
# helm uninstall ark_cloudconfig
#
###########################################################################################################

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
ARG MVN_VER="3.8.7"
ARG MVN_SRC="https://dlcdn.apache.org/maven/maven-3/${MVN_VER}/binaries/apache-maven-${MVN_VER}-bin.tar.gz"

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
ENV MVN_VER="3.8.7"
ENV MVN_SRC="https://dlcdn.apache.org/maven/maven-3/${MVN_VER}/binaries/apache-maven-${MVN_VER}-bin.tar.gz"

WORKDIR "/src"

# First, install the JDK
RUN yum update -y && yum -y install java-1.8.0-openjdk-devel git && yum clean all

# Next, the stuff that will be needed for the build
COPY "mvn" "/usr/bin"
ADD "${MVN_SRC}" "/"
RUN echo "Installing Maven ${MVN_VER}..." && tar -C / -xzf "/apache-maven-${MVN_VER}-bin.tar.gz" && mv -vf "/apache-maven-${MVN_VER}" "/mvn"
RUN echo "Cloning version [${VER}] from [${SRC}]..." && git clone -b "${VER}" "${SRC}" . && ls -l && mvn clean verify

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
ARG APP_UID="1997"
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

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="Cloudconfig" \
      VERSION="${VER}"

# Environment variables
ENV APP_UID="${APP_UID}" \
    APP_GID="${APP_GID}" \
    APP_USER="${APP_USER}" \
    APP_GROUP="${APP_GROUP}" \
    JAVA_HOME="/usr/lib/jvm/java" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8" \
    BASE_DIR="${BASE_DIR}" \ 
    DATA_DIR="${DATA_DIR}" \
    TEMP_DIR="${TEMP_DIR}" \
    HOME_DIR="${HOME_DIR}" \
    EXE_JAR="config-server-${VER}.jar" \
    MAIN_CONF="${MAIN_CONF}"

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
RUN groupadd --system --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --system --uid "${APP_UID}" --gid "${APP_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}"

#
# COPY the application war files
#
COPY --from=src "/src/target/${EXE_JAR}" "${BASE_DIR}/${EXE_JAR}"
ADD --chown="${APP_USER}:${APP_GROUP}" "entrypoint" "/entrypoint"

RUN rm -rf /tmp/* && \
    mkdir -p "${TEMP_DIR}" "${DATA_DIR}" && \
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}" 

USER "${APP_USER}"
EXPOSE 9999
VOLUME [ "${DATA_DIR}" ]
ENTRYPOINT [ "/entrypoint" ]
