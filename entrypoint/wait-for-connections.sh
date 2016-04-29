#!/bin/bash
set -e

php /var/www/html/server/yii init/wait-for-connections
sleep 2

exec "$@"