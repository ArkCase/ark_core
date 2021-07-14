#!/bin/sh
set -eu

# Run it!
exec java -jar /app/config-server.jar --spring.config.location=file:application.yml
