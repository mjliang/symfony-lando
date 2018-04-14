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

cat >$1/.lando.yml <<EOL
name: $(basename "$1")
recipe: lemp
config:
  webroot: public
  database: mariadb

services:
  appserver:
    config:
      server: nginx.conf

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

cat >$1/nginx.conf <<EOL
server {
    listen       443 ssl;
    listen       80;
    listen   [::]:80 default ipv6only=on;
    server_name  localhost;

    ssl_certificate      /certs/cert.pem;
    ssl_certificate_key  /certs/cert.key;

    root   \${LANDO_WEBROOT};
    index index.php index.html index.htm;

    location / {
        # try to serve file directly, fallback to index.php
        try_files \$uri /index.php\$is_args\$args;
    }

    location ~ ^/index\.php(/|\$) {
        fastcgi_buffers 256 128k;
        fastcgi_connect_timeout 300s;
        fastcgi_send_timeout 300s;
        fastcgi_read_timeout 300s;
        fastcgi_pass fpm:9000;
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;

        # optionally set the value of the environment variables used in the application
        # fastcgi_param APP_ENV prod;
        # fastcgi_param APP_SECRET <app-secret-id>;
        # fastcgi_param DATABASE_URL "mysql://db_user:db_pass@host:3306/db_name";

        # When you are using symlinks to link the document root to the
        # current version of your application, you should pass the real
        # application path instead of the path to the symlink to PHP
        # FPM.
        # Otherwise, PHP's OPcache may not properly detect changes to
        # your PHP files (see https://github.com/zendtech/ZendOptimizerPlus/issues/126
        # for more information).
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT \$realpath_root;
        # Prevents URIs that include the front controller. This will 404:
        # http://domain.tld/index.php/some-path
        # Remove the internal directive to allow URIs like this
        internal;
    }
}

EOL
