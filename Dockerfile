###########################################################################################################
#
# How to build:
#
# docker build -t 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_core:latest .
# docker push 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_core:latest
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
ARG VER="2021.03.19"
ARG PKG="core"
ARG TOMCAT_VER="9.0.50"
ARG TOMCAT_MAJOR_VER="9"
ARG TOMCAT_SRC="https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VER}/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz"
ARG YARN_SRC="https://dl.yarnpkg.com/rpm/yarn.repo"

FROM 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base:latest

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG PKG
ARG TOMCAT_VER
ARG TOMCAT_MAJOR_VER
ARG APP_UID="1997"
ARG APP_GID="${APP_UID}"
ARG APP_USER="${PKG}"
ARG APP_GROUP="${APP_USER}"
ARG BASE_DIR="/app"
ARG DATA_DIR="${BASE_DIR}/data"
ARG HOME_DIR="${BASE_DIR}/home"
ARG CONF_DIR="${BASE_DIR}/conf"
ARG TEMP_DIR="${BASE_DIR}/tmp"
ARG WORK_DIR="${BASE_DIR}/work"
ARG RESOURCE_PATH="artifacts"

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
    WORK_DIR="${WORK_DIR}"

WORKDIR "${BASE_DIR}"

#
# Create the requisite user and group
#
RUN groupadd --system --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --system --uid "${APP_UID}" --gid "${APP_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}"

RUN rm -rf /tmp/* && \
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}" 

##################################################### ARKCASE: BELOW ###############################################################

ARG BUILD_SERVER="iad032-1san01.appdev.armedia.com"

ARG VER
ARG TOMCAT_VER
ARG TOMCAT_MAJOR_VER
ARG SYMMETRIC_KEY="9999999999999999999999"
ARG RESOURCE_PATH="artifacts"
ARG YARN_SRC
ARG TOMCAT_SRC
ARG TOMCAT_VER

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

#################
# Build Arkcase
#################
ENV ARKCASE_APP="/app/arkcase" \
    NODE_ENV="production" \
    PATH="${PATH}:/app/tomcat/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin" \
    SSL_CERT="/etc/tls/crt/arkcase-server.crt" \
    SSL_KEY="/etc/tls/private/arkcase-server.pem" \
    TEMP="${WORK_DIR}" \
    TMP="${WORK_DIR}"

COPY "${RESOURCE_PATH}/server.xml" \
     "${RESOURCE_PATH}/logging.properties" \
     "${RESOURCE_PATH}/arkcase-server.crt" \
     "${RESOURCE_PATH}/arkcase-server.pem" ./

#
# TODO: These two are much more cleanly done using Maven and its dependency retrieval mechanisms
#
#RUN curl https://project.armedia.com/nexus/repository/arkcase/com/armedia/acm/acm-standard-applications/arkcase/${VER}/arkcase-${VER}.war -o /app/arkcase-${VER}.war
#RUN curl https://project.armedia.com/nexus/repository/arkcase/com/armedia/arkcase/arkcase-config-core/${VER}/arkcase-config-core-${VER}.zip -o "/tmp/arkcase-config-core-${VER}.zip"

# ADD yarn repo and nodejs package
ADD "${YARN_SRC}" "/etc/yum.repos.d/"
ADD "${TOMCAT_SRC}" "/app"

#  \
RUN yum -y update && \
    # Nodejs prerequisites to install native-addons from npm
    yum -y install \
        epel-release && \
    yum -y install \
        gcc \
        gcc-c++ \
        ImageMagick \
        ImageMagick-devel \
        java-1.8.0-openjdk-devel \
        make \
        nodejs \
        qpdf \
        openssl \
        openldap-clients \
        supervisor \
        tesseract \
        tesseract-osd \
        unzip \
        wget \
        yarn \
        zip \
    && \
    yum -y clean all

ADD --chown="${APP_USER}:${APP_GROUP}" "arkcase.war" "/app/arkcase.war"

    #unpack tomcat tar to tomcat directory
RUN tar -xf "apache-tomcat-${TOMCAT_VER}.tar.gz" && \
    mv "apache-tomcat-${TOMCAT_VER}" "tomcat" && \
    rm "apache-tomcat-${TOMCAT_VER}.tar.gz" &&\
    # Removal of default/unwanted Applications
    rm -rf "tomcat/webapps"/* "tomcat/temp"/* "tomcat/bin"/*.bat && \
    mv "server.xml" "logging.properties" "tomcat/conf/" && \
    mkdir -p "/tomcat/logs" &&\
    mv "/app/arkcase.war" "/app/tomcat/arkcase.war" && \
    mkdir -p "/app/tomcat/webapps/arkcase" && \
    cd "/app/tomcat/webapps/arkcase" && \
    jar xvf "/app/tomcat/arkcase.war" && \
    rm "/app/tomcat/arkcase.war" && \
    rm "/app/tomcat/webapps/arkcase/WEB-INF/lib"/postgresql-*.jar && \ 
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    #### chown -R tomcat:tomcat /app && \
    chmod u+x "/app/tomcat/bin"/*.sh

RUN ln -s "/usr/bin/convert" "/usr/bin/magick" && \
    ln -s "/usr/share/tesseract/tessdata/configs/pdf" "/usr/share/tesseract/tessdata/configs/PDF" && \
    rm -rf /tmp/* 
    #mkdir -p /arkcase/runtime/default/spring/ && \
    #chown -R "${APP_USER}:${APP_GROUP}" /arkcase

##################################################### ARKCASE: ABOVE ###############################################################

ADD --chown="${APP_USER}:${APP_GROUP}" "postgresql-42.5.2.jar" "/app/tomcat/lib/postgresql-42.5.2.jar"
ADD --chown="${APP_USER}:${APP_GROUP}" "samba.crt" "/app/samba.crt"

RUN keytool -keystore "${JAVA_HOME}/jre/lib/security/cacerts" -storepass changeit -importcert -trustcacerts -file "/app/samba.crt" -alias samba -noprompt

ADD --chown="${APP_USER}:${APP_GROUP}" "entrypoint" "/entrypoint"
ADD "arkcase.ini" "/etc/supervisord.d/"

USER "${APP_USER}"
RUN mkdir -p /app/tomcat/bin/logs/ && \
    mkdir -p /app/logs

USER "root"

EXPOSE 8080

# These may have to disappear in openshift
VOLUME [ "${CONF_DIR}" ]
VOLUME [ "${DATA_DIR}" ]
VOLUME [ "${WORK_DIR}" ]

ENTRYPOINT [ "/entrypoint" ]
