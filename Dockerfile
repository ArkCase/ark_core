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
ARG ACM_GID="10000"
ARG ACM_GROUP="acm"
ARG BASE_DIR="/app"
ARG DATA_DIR="${BASE_DIR}/data"
ARG HOME_DIR="${BASE_DIR}/home"
ARG CONF_DIR="${BASE_DIR}/conf"
ARG TEMP_DIR="${HOME_DIR}/tmp"
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
    HOME_DIR="${HOME_DIR}" \
    TEMP_DIR="${TEMP_DIR}" \
    TOMCAT_HOME="${BASE_DIR}/tomcat"

WORKDIR "${BASE_DIR}"

#
# Create the requisite user and group
#
RUN groupadd --system --gid "${ACM_GID}" "${ACM_GROUP}" && \
    groupadd --system --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --system --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}"

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
    PATH="${PATH}:${TOMCAT_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin" \
    SSL_CERT="/etc/tls/crt/arkcase-server.crt" \
    SSL_KEY="/etc/tls/private/arkcase-server.pem" \
    TEMP="${TEMP_DIR}" \
    TMP="${TEMP_DIR}"

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
        apr-devel \
        gcc \
        gcc-c++ \
        ImageMagick \
        ImageMagick-devel \
        java-1.8.0-openjdk-devel \
        make \
        nodejs \
        openldap-clients \
        openssl \
        openssl-devel \
        qpdf \
        redhat-rpm-config \
        sudo \
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
    mv "/app/arkcase.war" "${TOMCAT_HOME}/arkcase.war" && \
    mkdir -p "${TOMCAT_HOME}/webapps/arkcase" && \
    cd "${TOMCAT_HOME}/webapps/arkcase" && \
    jar xvf "${TOMCAT_HOME}/arkcase.war" && \
    rm "${TOMCAT_HOME}/arkcase.war" && \
    rm "${TOMCAT_HOME}/webapps/arkcase/WEB-INF/lib"/postgresql-*.jar && \ 
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    chmod u+x "${TOMCAT_HOME}/bin"/*.sh && \
    mkdir -p "${TOMCAT_HOME}/bin/native" && \
    tar -C "${TOMCAT_HOME}/bin/native" -xzvf "${TOMCAT_HOME}/bin/tomcat-native.tar.gz" --strip-components=1 && \
    pushd "${TOMCAT_HOME}/bin/native/native" && \
    ./configure --with-apr="/usr/bin/apr-1-config" --with-java-home="${JAVA_HOME}" --with-ssl=yes --prefix="${TOMCAT_HOME}" && \
    make && \
    make install && \
    popd && \
    rm -rf "${TOMCAT_HOME}/bin/native"

ENV LD_LIBRARY_PATH="${TOMCAT_HOME}:${LD_LIBRARY_PATH}"

RUN ln -s "/usr/bin/convert" "/usr/bin/magick" && \
    ln -s "/usr/share/tesseract/tessdata/configs/pdf" "/usr/share/tesseract/tessdata/configs/PDF" && \
    rm -rf /tmp/* 
    #mkdir -p /arkcase/runtime/default/spring/ && \
    #chown -R "${APP_USER}:${APP_GROUP}" /arkcase

##################################################### ARKCASE: ABOVE ###############################################################

ADD --chown="${APP_USER}:${APP_GROUP}" "postgresql-42.5.2.jar" "${TOMCAT_HOME}/lib/postgresql-42.5.2.jar"

ADD --chown="${APP_USER}:${APP_GROUP}" "entrypoint" "/entrypoint"

COPY --chown=root:root update-ssl /
COPY --chown=root:root 00-update-ssl /etc/sudoers.d
RUN chmod 0640 /etc/sudoers.d/00-update-ssl && \
    sed -i -e "s;\${ACM_GROUP};${ACM_GROUP};g" /etc/sudoers.d/00-update-ssl

USER "${APP_USER}"
WORKDIR "${HOME_DIR}"
RUN mkdir -p "${TOMCAT_HOME}/bin/logs" && \
    mkdir -p "${TEMP_DIR}" && \
    mkdir -p "${HOME_DIR}/logs"

EXPOSE 8080

# These may have to disappear in openshift
VOLUME [ "${CONF_DIR}" ]
VOLUME [ "${DATA_DIR}" ]
VOLUME [ "${HOME_DIR}" ]

ENTRYPOINT [ "/entrypoint" ]
