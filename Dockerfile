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

ARG CW_VER="1.7.1"
ARG CW_SRC="com.armedia.acm:curator-wrapper:${CW_VER}:jar:exe"
ARG CW_REPO="https://nexus.armedia.com/repository/arkcase"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base-tomcat"
ARG BASE_VER="9"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}:${BASE_VER_PFX}${BASE_VER}"

FROM "${BASE_IMG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
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
    LOGS_DIR="${LOGS_DIR}"

WORKDIR "${BASE_DIR}"

##################################################### RUNTIME: BELOW ###############################################################

#
# Some Tomcat settings
#
ENV CATALINA_TMPDIR="${TEMP_DIR}/tomcat" \
    CATALINA_OUT="${LOGS_DIR}/catalina.out"

#
# Create some required directories
#
RUN mkdir -p \
        "${TEMP_DIR}" \
        "${WORK_DIR}" \
        "${LOGS_DIR}" \
        "${CATALINA_TMPDIR}"

#
# Create the requisite user and group
#
RUN groupadd --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}"

RUN rm -rf /tmp/* && \
    chown -R "${APP_USER}:${ACM_GROUP}" "${BASE_DIR}" && \
    chmod -R "ug=rwX,o=" "${BASE_DIR}"

ARG VER
ARG JAVA

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

ENV WEBAPPS_DIR="${TOMCAT_HOME}/webapps" \
    NODE_ENV="production" \
    PATH="${PATH}:${TOMCAT_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin" \
    TEMP="${TEMP_DIR}" \
    TMP="${TEMP_DIR}"

#
# Install extra software
#
RUN set-java "${JAVA}" && \
    yum -y install \
        epel-release \
      && \
    yum -y install \
        ImageMagick \
        ImageMagick-devel \
        fontconfig \
        openldap-clients \
        openssl \
        poppler-utils \
        qpdf \
        sudo \
        tesseract \
        tesseract-osd \
        unzip \
        wget \
        xmlstarlet \
        zip \
      && \
    yum -y clean all

RUN ln -s "/usr/bin/convert" "/usr/bin/magick" && \
    ln -s "/usr/share/tesseract/tessdata/configs/pdf" "/usr/share/tesseract/tessdata/configs/PDF" && \
    rm -rf /tmp/*

#
# Deploy the ArkCase stuff
#
COPY "artifacts/" "${TOMCAT_HOME}/conf/"
RUN mkdir -vp "${WEBAPPS_DIR}" && \
    chown -R "${APP_USER}:${ACM_GROUP}" "${BASE_DIR}" && \
    chmod -R "ug=rwX,o=" "${TOMCAT_HOME}" && \
    chmod "ug=rwx,o=" "${TOMCAT_HOME}/bin"/*.sh

##################################################### RUNTIME: ABOVE ###############################################################

ADD --chown="${APP_USER}:${ACM_GROUP}" "entrypoint" "/entrypoint"

COPY --chown=root:root become-developer run-developer tomcat /usr/local/bin/
COPY --chown=root:root 02-developer-mode /etc/sudoers.d
RUN chmod 0640 /etc/sudoers.d/01-developer-mode && \
    sed -i -e "s;\${ACM_GROUP};${ACM_GROUP};g" /etc/sudoers.d/01-developer-mode

RUN mvn-get "${CW_SRC}" "${CW_REPO}" "/usr/local/bin/curator-wrapper.jar"

USER "${APP_USER}"
WORKDIR "${HOME_DIR}"

RUN mkdir -p "${HOME_DIR}/.postgresql" && ln -svf "${CA_TRUSTS_PEM}" "${HOME_DIR}/.postgresql/root.crt"

ENTRYPOINT [ "/entrypoint" ]
