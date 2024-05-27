#!/bin/sh

set -eux

readonly HTTP_USER=nginx
readonly HTTP_GROUP=nginx

readonly FCGI_SOCKET=/var/run/fcgiwrap.sock
readonly FCGI_PROGRAM=/usr/bin/fcgiwrap
# Defaults from
# https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine-slim/Dockerfile
readonly GID="${OVERRIDE_GID:-101}"
readonly UID="${OVERRIDE_GID:-101}"

if [ -z "${BASE_URL+x}" ]; then
  echo 'using default base_url'
else
  echo "overriding base_url with ${BASE_URL}"
  # We need to set a variable with a literal dollar-sign to an interpolated
  # variable which needs to be double-quoted. So:
  echo 'our $base_url = "'"${BASE_URL}"'";' >> /etc/gitweb.conf 
fi

# We could do this in Dockerfile but it's as easy to do at runtime.

# Only user in `users`
deluser guest
# We don't have "allow duplicate" so get rid of users first.
delgroup users

# Get rid of existing user (will also delete group)
deluser nginx
echo "recreating user nginx with uid:gid ${UID}:${GID}"
# -D -H: No password, no homedir.
addgroup -g "${GID}" nginx
adduser -u "${UID}" -D -H -g "nginx within docker" nginx nginx

env -i /usr/bin/spawn-fcgi \
  -s "${FCGI_SOCKET}" \
  -F 4 \
  -u "${HTTP_USER}" \
  -g "${HTTP_GROUP}" \
  -U "${HTTP_USER}" \
  -G "${HTTP_GROUP}" \
  -- \
  "${FCGI_PROGRAM}" \
  -f

doas -u nginx /usr/local/bin/repomng &

# This runs /docker-entrypoint.d hooks, then the command.
exec /docker-entrypoint.sh "$@"
