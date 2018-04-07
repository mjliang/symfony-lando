#!/usr/bin/env bash

if [[ ! $# -eq 1 ]] ; then
    echo "Usage: $0 <path>"
    exit 1
fi

if [[ ! -d $1 ]] ; then
    mkdir -p "$1"
    [[ $? -ne 0 ]] && exit 1
fi

docker run --rm --interactive --tty \
    --volume $(cd "$1" && pwd):/app \
    --user $(id -u):$(id -g) \
    composer create-project symfony/skeleton .
[[ $? -ne 0 ]] && exit 1

if [[ ! -f $1/.lando.yml ]] ; then
    cat >$1/.lando.yml <<EOL
name: $(basename "$1")
recipe: lemp
config:
  webroot: public
  database: mariadb

tooling:
  sf:
    service: appserver
    description: Run Symfony commands
    cmd:
      - bin/console

events:
  post-start:
    appserver: "composer install --working-dir=\$LANDO_MOUNT"

EOL
fi
