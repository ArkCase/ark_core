###########################################################################################################
#
# How to build:
#
# docker build -t ${BASE_REGISTRY}/arkcase/core:latest .
# docker push ${BASE_REGISTRY}/arkcase/core:latest
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
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="2021.03.25"
ARG TOMCAT_VER="9.0.50"
ARG TOMCAT_MAJOR_VER="9"
ARG TOMCAT_SRC="https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VER}/v${TOMCAT_VER}/bin/apache-tomcat-${TOMCAT_VER}.tar.gz"
ARG YARN_SRC="https://dl.yarnpkg.com/rpm/yarn.repo"
ARG ARKCASE_SRC="https://project.armedia.com/nexus/repository/arkcase/com/armedia/acm/acm-standard-applications/arkcase/${VER}/arkcase-${VER}.war"
ARG BASE_REGISTRY
ARG BASE_REPO="arkcase/base"
ARG BASE_TAG="8.7.0"

FROM "${BASE_REGISTRY}/${BASE_REPO}:${BASE_TAG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG TOMCAT_VER
ARG TOMCAT_MAJOR_VER
ARG ARKCASE_SRC
ARG APP_UID="1997"
ARG APP_GID="${APP_UID}"
ARG APP_USER="core"
ARG APP_GROUP="${APP_USER}"
ARG ACM_GID="10000"
ARG ACM_GROUP="acm"
ARG BASE_DIR="/app"
ARG DATA_DIR="${BASE_DIR}/data"
ARG LOGS_DIR="${BASE_DIR}/logs"
ARG HOME_DIR="${BASE_DIR}/home"
ARG TEMP_DIR="${HOME_DIR}/tmp"
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
    TOMCAT_HOME="${TOMCAT_HOME}"

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

ARG VER
ARG TOMCAT_VER
ARG TOMCAT_MAJOR_VER
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
ENV ARKCASE_APP="${BASE_DIR}/arkcase" \
    NODE_ENV="production" \
    PATH="${PATH}:${TOMCAT_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin" \
    TEMP="${TEMP_DIR}" \
    TMP="${TEMP_DIR}"

COPY "${RESOURCE_PATH}/server.xml" \
     "${RESOURCE_PATH}/logging.properties" ./

#
# TODO: This is done much more cleanly with Maven and its dependency retrieval mechanisms
#
ADD --chown="${APP_USER}:${APP_GROUP}" "${ARKCASE_SRC}" "${BASE_DIR}/arkcase.war"

# ADD yarn repo and nodejs package
ADD "${YARN_SRC}" "/etc/yum.repos.d/"
ADD "${TOMCAT_SRC}" "${BASE_DIR}"

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

RUN tar -xf "apache-tomcat-${TOMCAT_VER}.tar.gz" && \
    mv "apache-tomcat-${TOMCAT_VER}" "tomcat" && \
    rm "apache-tomcat-${TOMCAT_VER}.tar.gz" && \
    # Removal of default/unwanted Applications
    rm -rf "${TOMCAT_HOME}/webapps"/* "${TOMCAT_HOME}/temp"/* "${TOMCAT_HOME}/bin"/*.bat

    # Compile the native connector
RUN mkdir -p "${TOMCAT_HOME}/bin/native" && \
    tar -C "${TOMCAT_HOME}/bin/native" -xzvf "${TOMCAT_HOME}/bin/tomcat-native.tar.gz" --strip-components=1 && \
    pushd "${TOMCAT_HOME}/bin/native/native" && \
    ./configure --with-apr="/usr/bin/apr-1-config" --with-java-home="${JAVA_HOME}" --with-ssl=yes --prefix="${TOMCAT_HOME}" && \
    make && \
    make install && \
    popd && \
    rm -rf "${TOMCAT_HOME}/bin/native"

    # Deploy the ArkCase stuff
RUN mv -vf "server.xml" "logging.properties" "${TOMCAT_HOME}/conf/" && \
    mkdir -vp "/tomcat/logs" && \
    mkdir -vp "${TOMCAT_HOME}/webapps/arkcase" && \
    cd "${TOMCAT_HOME}/webapps/arkcase" && \
    jar xvf "${BASE_DIR}/arkcase.war" && \
    rm -vf "${BASE_DIR}/arkcase.war" && \
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    chmod u+x "${TOMCAT_HOME}/bin"/*.sh

ENV LD_LIBRARY_PATH="${TOMCAT_HOME}:${LD_LIBRARY_PATH}"

RUN ln -s "/usr/bin/convert" "/usr/bin/magick" && \
    ln -s "/usr/share/tesseract/tessdata/configs/pdf" "/usr/share/tesseract/tessdata/configs/PDF" && \
    rm -rf /tmp/* 
    #mkdir -p /arkcase/runtime/default/spring/ && \
    #chown -R "${APP_USER}:${APP_GROUP}" /arkcase

##################################################### ARKCASE: ABOVE ###############################################################

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
VOLUME [ "${DATA_DIR}" ]
VOLUME [ "${HOME_DIR}" ]
VOLUME [ "${LOGS_DIR}" ]

# These are required for Tomcat
VOLUME [ "${TOMCAT_HOME}/logs" ]
VOLUME [ "${TOMCAT_HOME}/temp" ]
VOLUME [ "${TOMCAT_HOME}/work" ]

ENTRYPOINT [ "/entrypoint" ]
