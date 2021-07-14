# Arkcase Cloud Config 
This Project produces Arkcase cloudconfig Community edition docker image.

## Build Docker image:
The community edition already built jar file is added in the conf directory. If you have forked the Arkcase Cloudconfig repo please build using maven build tool. Once it got built use the `RESOURCE_PATH` argument with path where the jar file is located

```bash
docker build -t arkcase-cloudconfig --build-arg RESOURCE_PATH=<PATH_TO_JAR> <DOCKERFILE_PATH>
```


