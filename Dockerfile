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
ARG FIPS=""
ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="4.0.0"
ARG JAVA="17"

ARG BASE_REGISTRY="${PUBLIC_REGISTRY}"
ARG BASE_REPO="arkcase/base-tomcat"
ARG BASE_VER="11"
ARG BASE_VER_PFX=""
ARG BASE_IMG="${BASE_REGISTRY}/${BASE_REPO}${FIPS}:${BASE_VER_PFX}${BASE_VER}"

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

ARG VER
ARG JAVA

ENV WEBAPPS_DIR="${TOMCAT_HOME}/webapps" \
    NODE_ENV="production"

#
# Create some required directories
#
RUN --mount=type=bind,target=/src \
    mkdir -p "${HOME_DIR}" "${WORK_DIR}" && \
    groupadd --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}" && \
    rm -rf /tmp/* && \
    set-java "${JAVA}" && \
    apt-get update && \
    apt-get -y install \
        imagemagick \
        libjmagick6-java \
        libjmagick6-jni \
        poppler-utils \
        qpdf \
        tesseract-ocr \
      && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    chmod go-r /var/log/fontconfig* && \
    ln -v "/usr/bin/convert" "/usr/bin/magick" && \
    ln -sv "tesseract-ocr/5" "/usr/share/tesseract" && \
    ln -v "/usr/share/tesseract/tessdata/configs/pdf" "/usr/share/tesseract/tessdata/configs/PDF" && \
    rm -rf /tmp/* && \
    ( tar --owner=root --group=root --mode=u=rwX,go=rX -cf - /src/artifacts ) | tar --strip-components=2 -C "${TOMCAT_HOME}/conf" -xvf - && \
    mkdir -vp "${WEBAPPS_DIR}" && \
    chown -R "${APP_USER}:${ACM_GROUP}" "${BASE_DIR}" && \
    chown -R "${APP_USER}:${APP_GROUP}" "${HOME_DIR}" && \
    chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}" && \
    chmod "u=rwx,g=rx,o=" "${TOMCAT_HOME}/bin"/*.sh && \
    chmod -R "ug=rwX,o=" "${TEMP_DIR}" "${TOMCAT_HOME}" && \
    chown root "${TOMCAT_HOME}/bin" && \
    chmod go-w "${TOMCAT_HOME}/bin" && \
    install -o "${APP_USER}" -g "${ACM_GROUP}" -m 0755 /src/entrypoint / && \
    install -o root -g root -m 0755 -t /usr/local/bin /src/become-developer /src/run-developer /src/tomcat && \
    install -o root -g root -m 0444 /src/02-developer-mode /etc/sudoers.d && \
    sed -i -e "s;\${ACM_GROUP};${ACM_GROUP};g" /etc/sudoers.d/02-developer-mode && \
    install -o root -g root -m 0444 /src/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml && \
    mkdir -p "${HOME_DIR}/.postgresql" && \
    ln -svf "${CA_TRUSTS_PEM}" "${HOME_DIR}/.postgresql/root.crt" && \
    chown -R "${APP_USER}:${APP_GROUP}" "${HOME_DIR}/.postgresql" && \
    chmod -R u=rwX,go= "${HOME_DIR}/.postgresql"

USER "${APP_USER}"
WORKDIR "${HOME_DIR}"
ENTRYPOINT [ "/entrypoint" ]
