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
ARG BASE_REPO="arkcase/base"
ARG BASE_TAG="8.8-01"
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="2.0.0"
ARG BLD="01"
ARG TOMCAT_VER="9.0.79"
ARG TOMCAT_MAJOR_VER="9"
ARG TOMCAT_SRC="https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VER}/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz"
ARG YARN_SRC="https://dl.yarnpkg.com/rpm/yarn.repo"
ARG CW_VER="1.4.4"
ARG CW_SRC="https://project.armedia.com/nexus/repository/arkcase/com/armedia/acm/curator-wrapper/${CW_VER}/curator-wrapper-${CW_VER}-exe.jar"

FROM "${PUBLIC_REGISTRY}/${BASE_REPO}:${BASE_TAG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG TOMCAT_VER
ARG TOMCAT_MAJOR_VER
ARG CW_SRC
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
      APP="ArkCase Core" \
      VERSION="${VER}"

#
# Environment variables
#
ENV APP_UID="${APP_UID}" \
    APP_USER="${APP_USER}" \
    APP_GID="${APP_GID}" \
    APP_GROUP="${APP_GROUP}" \
    JAVA_HOME="/usr/lib/jvm/java" \
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
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}" 

##################################################### ARKCASE: BELOW ###############################################################

ARG VER
ARG TOMCAT_VER
ARG TOMCAT_MAJOR_VER
ARG RESOURCE_PATH="artifacts"
ARG YARN_SRC
ARG TOMCAT_SRC
ARG TOMCAT_VER
ARG WEBAPPS_DIR="${TOMCAT_HOME}/webapps"

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

#################
# Build Arkcase
#################
ENV WEBAPPS_DIR="${WEBAPPS_DIR}" \
    NODE_ENV="production" \
    PATH="${PATH}:${TOMCAT_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin" \
    TEMP="${TEMP_DIR}" \
    TMP="${TEMP_DIR}"

COPY "${RESOURCE_PATH}/server.xml" \
     "${RESOURCE_PATH}/logging.properties" \
     "${RESOURCE_PATH}/catalina.properties" ./

# ADD yarn repo and nodejs package
ADD "${YARN_SRC}" "/etc/yum.repos.d/"

# Nodejs prerequisites to install native-addons from npm
RUN yum -y install \
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
        xmlstarlet \
        yarn \
        zip \
    && \
    yum -y clean all

RUN curl -K --fail "${TOMCAT_SRC}" | tar -xzvf - && \
    mv "apache-tomcat-${TOMCAT_VER}" "tomcat" && \
    # Removal of default/unwanted Applications
    rm -rf "${TOMCAT_HOME}/webapps"/* "${TOMCAT_HOME}/temp"/* "${TOMCAT_HOME}/bin"/*.bat

    # Compile the native connector
RUN mkdir -p "${TOMCAT_HOME}/bin/native" && \
    tar -C "${TOMCAT_HOME}/bin/native" -xzvf "${TOMCAT_HOME}/bin/tomcat-native.tar.gz" --strip-components=1 && \
    pushd "${TOMCAT_HOME}/bin/native/native" && \
    ./configure --prefix="${TOMCAT_HOME}" && \
    make && \
    make install && \
    popd && \
    rm -rf "${TOMCAT_HOME}/bin/native"

    # Deploy the ArkCase stuff
RUN mv -vf "server.xml" "logging.properties" "catalina.properties" "${TOMCAT_HOME}/conf/" && \
    mkdir -vp "${WEBAPPS_DIR}" && \
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    chmod u+x "${TOMCAT_HOME}/bin"/*.sh

# TODO: Re-enable this when on Java 11 ... Java 8 is SIGSEGV
# ENV LD_LIBRARY_PATH="${TOMCAT_HOME}/lib:${LD_LIBRARY_PATH}"
ENV CATALINA_TMPDIR="${TEMP_DIR}/tomcat" \
    CATALINA_OUT="${LOGS_DIR}/catalina.out"

RUN ln -s "/usr/bin/convert" "/usr/bin/magick" && \
    ln -s "/usr/share/tesseract/tessdata/configs/pdf" "/usr/share/tesseract/tessdata/configs/PDF" && \
    rm -rf /tmp/* 

##################################################### ARKCASE: ABOVE ###############################################################

ADD --chown="${APP_USER}:${APP_GROUP}" "entrypoint" "/entrypoint"

COPY --chown=root:root add-developer /usr/local/bin/
COPY --chown=root:root 01-add-developer /etc/sudoers.d
RUN chmod 0640 /etc/sudoers.d/01-add-developer && \
    sed -i -e "s;\${ACM_GROUP};${ACM_GROUP};g" /etc/sudoers.d/01-add-developer

RUN curl -L -o "/usr/local/bin/curator-wrapper.jar" "${CW_SRC}"

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
