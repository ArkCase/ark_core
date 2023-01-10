# Arkcase Cloud Config 
This Project produces Arkcase cloudconfig Community edition docker image.

## How to build:

docker build -t 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_cloudconfig:latest .

docker push 345280441424.dkr.ecr.ap-south-1.amazonaws.com/ark_cloudconfig:latest

## How to run: (Helm)

helm repo add arkcase https://arkcase.github.io/ark_helm_charts/

helm install ark_cloudconfig arkcase/ark_cloudconfig

helm uninstall ark_cloudconfig

