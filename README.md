# Local readme

I need to control the UID and GID that this whole mess runs as.

* `/etc/nginx/nginx.conf` contains `user nginx;`
  * This is coming from the install I think?
  * No mention of users in the local `default.conf` which is good at least
* Base `nginx` images: [`alpine-slim`'s `Dockerfile`](https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine-slim/Dockerfile) runs `addgroup -g 101 -S nginx` and `adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx` right at the beginning
  * No further mention of the user
  * No mention of the user in [`alpine`'s Dockerfile](https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile)
* gifnksm's [Dockerfile](https://github.com/gifnksm/git-http-server/blob/master/Dockerfile) runs:  `adduser git -h /var/lib/git -D` and `adduser nginx git` then does `git config --system`
* Base nginx [entrypoint.sh](https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine-slim/docker-entrypoint.sh) just runs hooks as whoever it is
* gifnksm's [entrypoint.sh](https://github.com/gifnksm/git-http-server/blob/master/scripts/entrypoint.sh) passes `nginx:nginx` to `spawn-fcgi` which uses them to set the ownership on the socket (`-U`, `-G`) and also to run as (`-u` and `-g`). It also passes `-u nginx` to the `repomng` thing it runs.

Constraints:
* nginx has to be able to read the `/srv/git` files to serve them directly
* nginx has to be able to read the unix socket to send to fcgiwrap
* [spawn-fcgi](https://linux.die.net/man/1/spawn-fcgi) has to be able to read the unix socket after it becomes the `-u/-g` user:group
* [spawn-fcgi](https://linux.die.net/man/1/spawn-fcgi) has to be able to read the `/srv/git` files after it becomes the `-u/-g` user:group
* `spawn-fcgi` has to *own* the /srv/git files to get git to shut up.

# Current path:

Run nginx and spawn-fcgi as the same user, with read/write access to /srv/git. Force the user to have a well-known UID and GID (1026:100) matching the owner in the outside world.

Note that internal user and group can be *named* nginx as long as the ids are right; this avoids needing to change the `nginx.conf` that specifies `user: nginx`. And nothing important is actually owned in the filesystem by the current users as best I can tell. (That is, inside the docker filesystem.) Maybe /var/cache/nginx matters?



# Rejected

Run nginx as the nginx user. Get the nginx group to something with read access to /srv/git since it won't care about being *owner*.

This is kind of the default setup but we still have to get the group to alias with something we can write into the file system, for the static file serving. So we'd end up trying to force matching GIDs, which is better than UIDs but not too much. (We would still have to fix the fcgi user to something that owns, to avoid that git error, but it would be a more isolated fix.)


# Original README follows:

# docker-git-http-server

Docker image for a Git HTTP server on Nginx.

Hosting git-http-backend & gitweb.

## Usage

Launch git-http-server with `docker`:

```
$ docker build . -t git-http-server
$ docker run \
  -d \
  -v $(pwd)/repos:/srv/git \
  -p "8080:80" \
  git-http-server
```

Launch git-http-server with `docker-compose`:

```console
$ docker-compose up -d
```
