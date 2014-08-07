# OpenProject Docker

```
WARNING: The OpenProject docker setup is still under heavy development.
```

A Dockerfile that installs OpenProject.
Actually it installs `libxml2-dev`, `libxslt-dev`, `g++`, `libpq-dev`, `sqlite3`, `ruby-sqlite3`, `libsqlite3-dev`, `ruby-mysql2`, `libmysql++-dev`, `libmagick++-dev`, and a fresh `openproject` stable release.

Please keep in mind, that we do **not** recommend to use the produced Docker image in production.
Why?
Because the docker team says that docker ["should not be used in production"](https://www.docker.io/learn_more/),
your data is not persisted (we'll talk about that later), there are no backups, no monitoring etc.

However, we strive to make our docker image secure and stable, so that we/you can use it in production in the future.

## Why Phusion?
This Docker image is based and reliant on phusion/passenger-ruby21 because of very good reasons, explained on this page:
 http://phusion.github.io/baseimage-docker/

Basically, starting with an OS image would leave the process naked and alone. After several days of attempting to make that work, I went on to see if any images already in the Docker repository would be of use. I tried two, before checking whether Phusion had a ruby package, since I already knew their base images are good from the other containers I've set-up.

## Installation

First [install docker](https://www.docker.io/). Then do the following to prepare for building an OpenProject image:

```bash
$ git clone https://github.com/coladict/openproject-docker.git
$ cd openproject-docker
$ ls ~/.ssh/
```

If you do not have a pair of files called `id_rsa` and `id_rsa.pub` you must create them by running:
```bash
$ ssh-keygen
```

Once you have those files, copy `id_rsa.pub` to the current location:
```bash
$ cp ~/.ssh/id_rsa.pub .
```

Before building the image you must edit `files/configuration.yml`, `files/database.yml` and `nginx-default` to your needs. The nginx settings `set_real_ip_from 172.17.42.1;`, `real_ip_header X-Forwarded-For;` and `real_ip_recursive off;` presume you are using a reverse proxy *and* that your host address is bound to `172.17.42.1` as shown later in this document.
Set-up your database as described in https://www.openproject.org/projects/openproject/wiki/Installation_OpenProject_3_0

**NOTE:** The current version of these files is taken from OpenProject stable release 3.0.8.

***WARNING:*** If you do not plan on using PostgreSQL for your database storage, stop right here and read the persistence notes!!!

Otherwise, make sure your PgSQL server is bound to the right IP addresses, by editing your `postgresql.conf` file's `listen_addresses` value. The comment you will find there tells lies that by default it is bound to all addresses. It is actually bound to `localhost`, when value is not set.

Now you must build the image (this will take some time):
```bash
$ docker build -t openproject:3.0 .
```

**NOTE:** depending on your docker installation, you might need to prepend `sudo ` to your `docker` commands or you may have to run `docker.io` or `sudo docker.io` instead.

## Usage
 
Before running an image you must first create several directories on your host machine. Here, we are using:
``/var/log/openproject/`` for the logs and
``/var/local/openproject/files/`` for user-uploaded files.
``/var/local/openproject/sqlite/`` if you are using SQLite.


To spawn a new instance of OpenProject on port 80 of your host machine run:
```bash
$ docker run -v /var/log/openproject:/home/app/openproject/log \
 -v /var/local/openproject/files:/home/app/openproject/files \
 --name proj_server --hostname ProjServ -p 80:80 \
 -d openproject:3.0
```

The `-p 80:3000` parameter tells Docker to forward the port from the container's port 3000 to host port 80. All parameters must be added before the image name `openproject:3.0`. Anything added after it is treated as a command that overrides the CMD parameter from the Dockerfile, but cannot override an ENTRYPOINT parameter.
The `--name` parameter sets a name that would otherwise be assigned randomly (for example `drunk_davinci` is one name we got randomly), that we can use in docker commands such as `inspect`, `start`, `stop`, `kill`, etc. Giving it a non-random name is more convenient for automation.
The `--hostname` parameter gives it the name that will appear when you connect a terminal to it, either via `attach` (thought that won't work well with a Phusion base-image) or through SSH. If left unset, it will use the container's short id, which is an internal value, different from the name and is a stringified number in hexadecimal format (probably a sha1 hash).
The `-d` parameter tells Docker to start the image in the background and print the container id to stdout.

You can the visit the following URL in a browser on your host machine to get started:

```
http://localhost
```

## Get a shell on your OpenProject image

To get the IP address of the container you will need to use this command

```bash
$ docker inspect -f "{{ .NetworkSettings.IPAddress }}" op_one
```
The `-f` parameter inputs formatting options as to which data we want to extract. Without it the `inspect` command would print all of the container's top-layer system data in JSON format.
Normally, unless that network has been allocated locally before Docker is installed, if this is your first container, the IP address should be something like 172.17.0.1

If you have followed the instructions conserning `id_rsa.pub`, you will not have any problems authenticating, and if you generated the key without a password, you should not be prompted for one.

## Further thoughts

### Setting timezone for accurate logs
Typically a docker container runs with the system clock, believing that it's set to UTC and that your server is running in that timezone, thus all timestamps in the logs will be printed under that assumption. A simple way to change this is to fire-up an SSH connection and go to `/etc`. Delete `localtime` and replace it with a symbolic link to the right file from `/usr/share/zoneinfo/`, then edit your timezone file with `nano` or your preferred editor.
To be sure all your processes take in the new settings, exit the SSH session and restart the container using `docker restart`.

### Persistence notes
If you choose to use SQLite, then wherever you choose to store it's files, you MUST link that whole directory (preferably it would be /home/app/openproject/db/sqlite for this example) to outside the docker image or you risk losing all of your data. You would need to add an additional parameter after "docker run", but before the image name:
`-v /var/local/openproject/sqlite:/home/app/openproject/db/sqlite`
This presumes you have created the appropriate directory on your host filesystem.

**SQLite3 failing**: SQLite is not officially supported in the current stable release 3.0.11. If you want to use it, you will need real to edit the project manually and know what you're doing.
 
If you have configured OpenProject to use/create local repositories, the place where you store those repositories must also be forwarded to the host.

#### Ensuring a consistant database IP address
Trying to connect to localhost (127.0.0.1) from a container, when the database is running outside it just won't work. It's all part of the isolation concept you're using Docker for in the first place. To connect to a database, either running on the host machine or in another container on it, you must ensure that the virtual interface docker0 always binds to the same IP address. Although it may seem like Docker always binds to 172.17.42.1, that is not guranteed. It is supposedly random, so we should make sure it is not.
The sloppy and problematic way to do it is by editing `/etc/network/interfaces`. The proper way to do it is by editing `/etc/default/docker.io` and adding the following line
```
DOCKER_OPTS="--bip=172.17.42.1/16"
```
This means that now your database host in database.yml must be `172.17.42.1`, as that is your host's address in the virtual network. **If your database is also in a container, make sure you forward it's port with `-p` when calling `docker run`.**

### E-Mail Setup

Please visit the `Modules -> Administration -> Settings -> Email notifications` page for further settings.

### OpenProject plug-ins

This installation does not come with any plugins or themes. If you wish to install such, you must edit `files/Gemfile.plugins` to include the ones you want. and uncomment the following line in Dockerfile by removing the # symbol:
```
#ADD files/Gemfile.plugins /home/app/openproject/Gemfile.plugins
```
This must be done before building the image.
### Automation notes
For getting the IP addresses of the containers on start-up I use the following script template:
```bash
while [ -z "$OPEN_PROJ ]; do
 sleep 2s;
 OPEN_PROJ=`(docker inspect -f "{{ \
 .NetworkSettings.IPAddress }}" op_one)`
 done;
```
After this, the address is added to the `/etc/hosts` file and the redirection is handled by nginx in our case, though that should work with any set-up.

### Features which we'd love to have

* make the admin change his password on the first login
* nice seed data
* an additional image (or instructions) for 'easy' development
* have a smaller image size (one can only dream)

## Contribute

We are happy for any contribution :) You may either

* make a Pull Request (which we favor ;))
* [open a new issue](https://www.openproject.org/projects/docker/work_packages/new) at our bug tracker
* or discuss [at the forums](https://www.openproject.org/projects/openproject/boards)

## License

This work is licensed under the GPLv3 - see [COPYRIGHT.md](COPYRIGHT.md) for details.

The Phuson Passenger Ruby Docker image is licensed under the [MIT license](PHUSION.LICENSE).

