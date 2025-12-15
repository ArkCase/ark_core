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
ARG VER="4.0.0"
ARG JAVA="17"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base-tomcat"
ARG BASE_VER="11"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}:${BASE_VER_PFX}${BASE_VER}"

FROM "${BASE_IMG}"

#
# Basic Parameters
#
ARG ARCH
ARG OS
ARG VER
ARG APP_UID="1997"
ARG APP_USER="core"
ARG APP_GID="${APP_UID}"
ARG APP_GROUP="${APP_USER}"

LABEL ORG="ArkCase LLC" \
      MAINTAINER="Armedia Devops Team <devops@armedia.com>" \
      APP="ArkCase Core Application" \
      VERSION="${VER}"

#
# Environment variables
#
ENV APP_UID="${APP_UID}" \
    APP_USER="${APP_USER}" \
    APP_GID="${APP_GID}" \
    APP_GROUP="${APP_GROUP}"

ENV HOME_DIR="${BASE_DIR}/home"
ENV WORK_DIR="${HOME_DIR}/work"

WORKDIR "${BASE_DIR}"

##################################################### RUNTIME: BELOW ###############################################################

#
# Create some required directories
#
RUN mkdir -p "${HOME_DIR}" "${WORK_DIR}"

#
# Create the requisite user and group
#
RUN groupadd --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}" && \
    rm -rf /tmp/* && \
    chown -R "${APP_USER}:${ACM_GROUP}" "${BASE_DIR}" && \
    chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}"

ARG VER
ARG JAVA

ENV WEBAPPS_DIR="${TOMCAT_HOME}/webapps" \
    NODE_ENV="production"

#
# Install extra software
#
RUN set-java "${JAVA}" && \
    apt-get -y install \
        imagemagick \
        libjmagick6-java \
        libjmagick6-jni \
        poppler-utils \
        qpdf \
        tesseract-ocr \
      && \
    apt-get clean

RUN ln -sv "/usr/bin/convert" "/usr/bin/magick" && \
    ln -sv "/usr/share/tesseract-ocr/4.00" "/usr/share/tesseract" && \
    ln -sv "/usr/share/tesseract/tessdata/configs/pdf" "/usr/share/tesseract/tessdata/configs/PDF" && \
    rm -rf /tmp/*

#
# Deploy the ArkCase stuff
#
COPY "artifacts/" "${TOMCAT_HOME}/conf/"
RUN mkdir -vp "${WEBAPPS_DIR}" && \
    chown -R "${APP_USER}:${ACM_GROUP}" "${BASE_DIR}" && \
    chmod -R "ug=rwX,o=" "${TOMCAT_HOME}" && \
    chmod "u=rwx,g=rx,o=" "${TOMCAT_HOME}/bin"/*.sh

##################################################### RUNTIME: ABOVE ###############################################################

COPY --chown="${APP_USER}:${ACM_GROUP}" --chmod=0755 "entrypoint" "/entrypoint"
COPY --chown=root:root --chmod=0755 become-developer run-developer tomcat /usr/local/bin/
COPY --chown=root:root --chmod=0444 01-developer-mode /etc/sudoers.d
RUN sed -i -e "s;\${ACM_GROUP};${ACM_GROUP};g" /etc/sudoers.d/01-developer-mode

USER "${APP_USER}"
WORKDIR "${HOME_DIR}"

ENTRYPOINT [ "/entrypoint" ]
