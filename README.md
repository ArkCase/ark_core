# ArkCase Tomcat Runner

This Project produces the main image which will run Tomcat properly configured for ArkCase. It does not contain the webapp itself. This image is meant to run as part of a helm chart, and through that helm chart the webapp is provided to it.

## How to build:

docker build -t public.ecr.aws/arkcase/core:latest .

