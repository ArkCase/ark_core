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
ADD --chown="${APP_USER}:${APP_GROUP}" "cloudconfig" "/cloudconfig"
ADD --chown="${APP_USER}:${APP_GROUP}" "arkcase" "/arkcase"
ADD "cloudconfig.ini" "arkcase.ini" "/etc/supervisord.d/"

RUN rm -rf /tmp/* && \
    mkdir -p "${TEMP_DIR}" "${DATA_DIR}" && \
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}" 

##################################################### ARKCASE: BELOW ###############################################################

ARG BUILD_SERVER=iad032-1san01.appdev.armedia.com

ARG ARKCASE_VERSION=2021.03.19
ARG TOMCAT_VERSION=9.0.50
ARG TOMCAT_MAJOR_VERSION=9
ARG SYMMETRIC_KEY=9999999999999999999999
ARG resource_path=artifacts
ARG MARIADB_CONNECTOR_VERSION=2.2.5

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

#################
# Build Arkcase
#################
ENV NODE_ENV="production" \
    ARKCASE_APP="/app/arkcase" \
    TMP=/app/arkcase/tmp \
    TEMP=/app/arkcase/tmp \
    PATH=$PATH:/app/tomcat/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin\
    SSL_CERT=/etc/tls/crt/arkcase-server.crt \
    SSL_KEY=/etc/tls/private/arkcase-server.pem
WORKDIR /app
COPY ${resource_path}/server.xml \
    ${resource_path}/logging.properties \
    ${resource_path}/arkcase-server.crt \
    ${resource_path}/arkcase-server.pem ./

#RUN curl https://project.armedia.com/nexus/repository/arkcase/com/armedia/acm/acm-standard-applications/arkcase/${ARKCASE_VERSION}/arkcase-${ARKCASE_VERSION}.war -o /app/arkcase-${ARKCASE_VERSION}.war


#RUN curl https://project.armedia.com/nexus/repository/arkcase/com/armedia/arkcase/arkcase-config-core/${ARKCASE_VERSION}/arkcase-config-core-${ARKCASE_VERSION}.zip -o /tmp/arkcase-config-core-${ARKCASE_VERSION}.zip

# ADD yarn repo and nodejs package
ADD https://dl.yarnpkg.com/rpm/yarn.repo /etc/yum.repos.d/yarn.repo
ADD https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz /app

#  \
RUN yum -y update && \
    mkdir -p ${ARKCASE_APP}/data/arkcase-home && \
    mkdir -p ${ARKCASE_APP}/common && \
    mkdir -p /etc/tls/private && \
    mkdir -p /etc/tls/crt && \
    yum -y install epel-release && \
    yum -y update && \
    # Nodejs prerequisites to install native-addons from npm
    yum install -y gcc gcc-c++ make openssl wget zip unzip supervisor nodejs yarn

ADD --chown="${APP_USER}:${APP_GROUP}" "arkcase.war" "/app/arkcase.war"
    #unpack tomcat tar to tomcat directory
RUN tar -xf apache-tomcat-${TOMCAT_VERSION}.tar.gz && \
    mv apache-tomcat-${TOMCAT_VERSION} tomcat && \
    rm apache-tomcat-${TOMCAT_VERSION}.tar.gz &&\
    # Removal of default/unwanted Applications
    rm -rf tomcat/webapps/* tomcat/temp/* tomcat/bin/*.bat && \
    mv server.xml logging.properties tomcat/conf/ && \
    mkdir -p /tomcat/logs &&\
    mv /app/arkcase.war /app/tomcat/arkcase.war && \
#    curl https://project.armedia.com/nexus/repository/arkcase/com/armedia/acm/acm-standard-applications/arkcase/${ARKCASE_VERSION}/arkcase-${ARKCASE_VERSION}.war -o /app/tomcat/arkcase.war && \
    mkdir -p /app/tomcat/webapps/arkcase && \
    cd /app/tomcat/webapps/arkcase && \
    jar xvf /app/tomcat/arkcase.war && \
    rm /app/tomcat/arkcase.war && \
    rm /app/tomcat/webapps/arkcase/WEB-INF/lib/postgresql-9.3-1100-jdbc41.jar && \ 
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    #### chown -R tomcat:tomcat /app && \
    chmod u+x /app/tomcat/bin/*.sh &&\
    # Add default SSL Keys
    mv /app/arkcase-server.crt  /etc/tls/crt/arkcase-server.crt &&\
    mv /app/arkcase-server.pem /etc/tls/private/arkcase-server.pem &&\
    chmod 644 /etc/tls/crt/* &&\
    chmod 666 /etc/pki/ca-trust/extracted/java/cacerts &&\
    # Encrypt Symmentric Key
    echo ${SYMMETRIC_KEY} > ${ARKCASE_APP}/common/symmetricKey.txt &&\
    openssl x509 -pubkey -noout -in ${SSL_CERT} -noout > ${ARKCASE_APP}/common/arkcase-server.pub &&\
    openssl rsautl -encrypt -pubin -inkey ${ARKCASE_APP}/common/arkcase-server.pub -in ${ARKCASE_APP}/common/symmetricKey.txt -out ${ARKCASE_APP}/common/symmetricKey.encrypted &&\
    rm ${ARKCASE_APP}/common/symmetricKey.txt &&\
    # Remove unwanted package
    yum clean all

RUN yum install -y tesseract tesseract-osd qpdf ImageMagick ImageMagick-devel && \
    ln -s /usr/bin/convert /usr/bin/magick &&\
    ln -s /usr/share/tesseract/tessdata/configs/pdf /usr/share/tesseract/tessdata/configs/PDF &&\
    yum update -y && yum clean all && rm -rf /tmp/*  
    #mkdir -p /arkcase/runtime/default/spring/ &&\
    #chown -R "${APP_USER}:${APP_GROUP}" /arkcase

RUN yum -y install openldap-clients
ENV CATALINA_OPTS="-Dacm.configurationserver.propertyfile=/app/home/.arkcase/acm/conf.yml -Dspring.profiles.active=ldap -Xms1024m -Xmx2048m"
ENV LD_LIBRARY_PATH="/app/home/.arkcase/libraries"
##################################################### ARKCASE: ABOVE ###############################################################

ADD --chown="${APP_USER}:${APP_GROUP}" "postgresql-42.5.2.jar" "/app/tomcat/lib/postgresql-42.5.2.jar"
ADD --chown="${APP_USER}:${APP_GROUP}" "samba.crt" "/app/samba.crt"

RUN /usr/bin/ln -s /app/data /app/home/.arkcase &&\
    mkdir -p /app/tomcat/bin/logs/ &&\
    mkdir -p /app/logs &&\
    keytool -keystore $JAVA_HOME/jre/lib/security/cacerts -storepass changeit -importcert -trustcacerts -file /app/samba.crt -alias samba -noprompt

EXPOSE 9999
VOLUME [ "${DATA_DIR}" ]
#ENTRYPOINT ["tail", "-f", "/dev/null"]

ENTRYPOINT [ "/usr/bin/supervisord", "-n" ]
