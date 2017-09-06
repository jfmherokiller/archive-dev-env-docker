#!/bin/sh
# `/sbin/setuser www-data` runs the given command as the user `www-data`.
# If you omit that part, the command will be run as root.
exec /sbin/setuser www-data /usr/local/bin/redis-server /etc/redis/redis.conf >>/var/log/redis.log 2>&1