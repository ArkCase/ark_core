FROM 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base_java8:latest
LABEL ORG="Armedia LLC" \
      VERSION="1.0" \
      IMAGE_SOURCE=https://github.com/ArkCase/ark_cloudconfig \
      MAINTAINER="Armedia LLC"
ARG RESOURCE_PATH="target" 
ENV CLOUD_CONFIG_VERSION="2021.03"
WORKDIR /app
RUN useradd --create-home --user-group arkcase \
        && mkdir /app/tmp \
        && chown -R arkcase:arkcase /app 

USER arkcase
#COPY the application war files
COPY --chown=arkcase ${RESOURCE_PATH}/config-server-${CLOUD_CONFIG_VERSION}-SNAPSHOT.jar /app/config-server.jar 
COPY --chown=arkcase ./conf/start.sh /app/start.sh

RUN chmod +x /app/start.sh
EXPOSE 9999

CMD [ "/app/start.sh" ]

