#!/bin/bash
here=$(realpath "$0")
here=$(dirname "$here")
cd "$here"
cloud_config_version="2021.03"
rm -rf artifacts
mkdir artifacts
echo "Downloading  config version $cloud_config_version"
aws s3 cp "s3://arkcase-container-artifacts/ark_cloudconfig/artifacts/config-server-${cloud_config_version}-SNAPSHOT.jar" artifacts/
aws s3 cp "s3://arkcase-container-artifacts/ark_cloudconfig/artifacts/start.sh" artifacts/