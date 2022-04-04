#!/bin/bash
here=$(realpath "$0")
here=$(dirname "$here")
cd "$here"
CLOUD_CONFIG_VERSION="2021.03.07"
rm -rf artifacts
mkdir artifacts
echo "Downloading config version $CLOUD_CONFIG_VERSION"
aws s3 cp "s3://arkcase-container-artifacts/ark_cloudconfig/artifacts/$CLOUD_CONFIG_VERSION/config-server.jar" artifacts/
aws s3 cp "s3://arkcase-container-artifacts/ark_cloudconfig/artifacts/$CLOUD_CONFIG_VERSION/start.sh" artifacts/
