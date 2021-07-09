#!/bin/sh

set -eu

repodir=/app/data
search_locations="file:$repodir,file:$repodir/labels,file:$repodir/ldap,file:$repodir/lookups,file:$repodir/rules"


# Run it!
exec java -jar /app/config-server.jar --spring.config.location=file:application.yml
