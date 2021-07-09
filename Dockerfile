FROM 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_base_java8:latest
WORKDIR /app
RUN useradd --create-home --user-group arkcase \
        && mkdir /app/tmp \
        && chown -R arkcase:arkcase /app 
        
    
USER arkcase
COPY --chown=arkcase ./config-server-2021.03-SNAPSHOT.jar /app/config-server.jar 
COPY --chown=arkcase ./start.sh /app/start.sh

RUN chmod +x /app/start.sh
EXPOSE 9999

CMD [ "/app/start.sh" ]

