###########################################################################################################
#
# How to build:
#
# docker build -t arkcase/core:latest .
#
# How to run: (Helm)
#
# helm repo add arkcase https://arkcase.github.io/ark_helm_charts/
# helm install core arkcase/core
# helm uninstall core
#
###########################################################################################################

#
# Basic Parameters
#
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="3.0.0"
ARG JAVA="11"
ARG TOMCAT_VER="9.0.106"
ARG TOMCAT_MAJOR_VER="9"
ARG TOMCAT_SRC="https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VER}/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz"
ARG TCNATIVE_VER="1.3.1"
ARG TCNATIVE_URL="https://archive.apache.org/dist/tomcat/tomcat-connectors/native/${TCNATIVE_VER}/source/tomcat-native-${TCNATIVE_VER}-src.tar.gz"

ARG CW_VER="1.5.0"
ARG CW_SRC="com.armedia.acm:curator-wrapper:${CW_VER}:jar:exe"
ARG CW_REPO="https://nexus.armedia.com/repository/arkcase"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base-java"
ARG BASE_VER="8"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}:${BASE_VER_PFX}${BASE_VER}"

FROM "${BASE_IMG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG TOMCAT_VER
ARG TOMCAT_MAJOR_VER
ARG CW_SRC
ARG CW_REPO
ARG APP_UID="1997"
ARG APP_USER="core"
ARG APP_GID="${APP_UID}"
ARG APP_GROUP="${APP_USER}"
ARG BASE_DIR="/app"
ARG HOME_DIR="${BASE_DIR}/home"
ARG TEMP_DIR="${HOME_DIR}/temp"
ARG WORK_DIR="${HOME_DIR}/work"
ARG LOGS_DIR="${BASE_DIR}/logs"
ARG TOMCAT_HOME="${BASE_DIR}/tomcat"
ARG RESOURCE_PATH="artifacts"

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="ArkCase Tomcat" \
      VERSION="${VER}"

#
# Environment variables
#
ENV APP_UID="${APP_UID}" \
    APP_USER="${APP_USER}" \
    APP_GID="${APP_GID}" \
    APP_GROUP="${APP_GROUP}" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8" \
    BASE_DIR="${BASE_DIR}" \ 
    HOME_DIR="${HOME_DIR}" \
    TEMP_DIR="${TEMP_DIR}" \
    WORK_DIR="${WORK_DIR}" \
    LOGS_DIR="${LOGS_DIR}" \
    TOMCAT_HOME="${TOMCAT_HOME}"

WORKDIR "${BASE_DIR}"

#
# Create the requisite user and group
#
RUN groupadd --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}"

RUN rm -rf /tmp/* && \
    chown -R "${APP_USER}:${ACM_GROUP}" "${BASE_DIR}" && \
    chmod -R "ug=rwX,o=" "${BASE_DIR}"

##################################################### RUNTIME: BELOW ###############################################################

ARG VER
ARG TOMCAT_VER
ARG TOMCAT_MAJOR_VER
ARG RESOURCE_PATH="artifacts"
ARG JAVA
ARG TOMCAT_SRC
ARG TOMCAT_VER
ARG TCNATIVE_URL
ARG WEBAPPS_DIR="${TOMCAT_HOME}/webapps"

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

ENV WEBAPPS_DIR="${WEBAPPS_DIR}" \
    NODE_ENV="production" \
    PATH="${PATH}:${TOMCAT_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin" \
    TEMP="${TEMP_DIR}" \
    TMP="${TEMP_DIR}"

COPY "${RESOURCE_PATH}/server.xml" \
     "${RESOURCE_PATH}/logging.properties" \
     "${RESOURCE_PATH}/catalina.properties" ./

RUN set-java "${JAVA}" && \
    yum -y install \
        epel-release \
      && \
    yum -y install \
        apr-devel \
        gcc \
        gcc-c++ \
        ImageMagick \
        ImageMagick-devel \
        fontconfig \
        make \
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
        xmlstarlet \
        zip \
      && \
    yum -y clean all

# Download and install Tomcat, and remove unwanted stuff
RUN mkdir -p "${TOMCAT_HOME}" && \
    curl -fsSL "${TOMCAT_SRC}" | tar --strip-components=1 -C "${TOMCAT_HOME}" -xzvf - && \
    rm -rf "${TOMCAT_HOME}/webapps"/* "${TOMCAT_HOME}/temp"/* "${TOMCAT_HOME}/bin"/*.bat

# Build the Tomcat native APR connector
RUN BUILD_DIR="/tmp/tcnative" && \
    mkdir -p "${BUILD_DIR}" && \
    pushd "${BUILD_DIR}" && \
    curl -fsSL "${TCNATIVE_URL}" | tar --strip-components=1 -xzvf - && \
    cd native && \
    ./configure --prefix="${TOMCAT_HOME}" && \
    make && \ 
    make install && \
    popd && \
    rm -rf "${BUILD_DIR}"

# Deploy the ArkCase stuff
RUN mv -vf "server.xml" "logging.properties" "catalina.properties" "${TOMCAT_HOME}/conf/" && \
    mkdir -vp "${WEBAPPS_DIR}" && \
    chown -R "${APP_USER}:${ACM_GROUP}" "${BASE_DIR}" && \
    chmod -R "ug=rwX,o=" "${TOMCAT_HOME}" && \
    chmod "ug=rwx,o=" "${TOMCAT_HOME}/bin"/*.sh

# Disable this for now ... Tomcat is *still* not happy ...
# ENV LD_LIBRARY_PATH="${TOMCAT_HOME}/lib:${LD_LIBRARY_PATH}"
ENV CATALINA_TMPDIR="${TEMP_DIR}/tomcat" \
    CATALINA_OUT="${LOGS_DIR}/catalina.out"

RUN ln -s "/usr/bin/convert" "/usr/bin/magick" && \
    ln -s "/usr/share/tesseract/tessdata/configs/pdf" "/usr/share/tesseract/tessdata/configs/PDF" && \
    rm -rf /tmp/* 

##################################################### RUNTIME: ABOVE ###############################################################

ADD --chown="${APP_USER}:${ACM_GROUP}" "entrypoint" "/entrypoint"

COPY --chown=root:root become-developer run-developer tomcat /usr/local/bin/
COPY --chown=root:root 01-developer-mode /etc/sudoers.d
RUN chmod 0640 /etc/sudoers.d/01-developer-mode && \
    sed -i -e "s;\${ACM_GROUP};${ACM_GROUP};g" /etc/sudoers.d/01-developer-mode

RUN mvn-get "${CW_SRC}" "${CW_REPO}" "/usr/local/bin/curator-wrapper.jar"

USER "${APP_USER}"
WORKDIR "${HOME_DIR}"
RUN mkdir -p \
        "${TEMP_DIR}" \
        "${WORK_DIR}" \
        "${CATALINA_TMPDIR}"

# These may have to disappear in openshift
VOLUME [ "${HOME_DIR}" ]
VOLUME [ "${LOGS_DIR}" ]
VOLUME [ "${WEBAPPS_DIR}" ]

ENTRYPOINT [ "/entrypoint" ]
