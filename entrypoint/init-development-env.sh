#!/bin/bash
set -e

composer install --working-dir /var/www/html/server
php /var/www/html/server/init --env=Development --overwrite=y

exec "$@"