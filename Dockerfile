#-- copyright
# OpenProject-docker is a set-up script for OpenProject using the
# 'Apache 2.0' licensed docker container engine. See
# http://docker.io and https://github.com/dotcloud/docker for details
#
# OpenProject is a project management system.
# Copyright (C) 2013 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 3.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT.md for more details.
#++

# DOCKER-VERSION 0.9.1
FROM phusion/passenger-ruby21:latest

MAINTAINER OpenProject Foundation (opf), info@openproject.org

ENV DEBIAN_FRONTEND noninteractive

# Get repositories
RUN apt-get update

# Install most missing things we need
# To minimize your image you should remove database packages you don't need
RUN apt-get -y install libxml2-dev libxslt-dev g++ libpq-dev sqlite3 ruby-sqlite3 libsqlite3-dev ruby-mysql2 libmysql++-dev libmagick++-dev && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Get stable version of openproject from the repository into app's home directory
RUN su -c "cd /home/app/ && git clone https://github.com/opf/openproject.git -b stable" app

RUN su -c "cd /home/app/openproject && bundle install --without development test --path vendor/bundle" app

# You must edit the configuration and database files before adding them
ADD files/configuration.yml /home/app/openproject/config/configuration.yml 
ADD files/database.yml /home/app/openproject/config/database.yml 

#ADD files/Gemfile.plugins /home/app/openproject/Gemfile.plugins

# Default installation steps as described in OpenProject's wiki
RUN su -c "cd /home/app/openproject && bundle exec rake generate_secret_token" app
RUN su -c "cd /home/app/openproject && bundle exec rake db:create:all" app
RUN su -c "cd /home/app/openproject && bundle exec rake db:migrate db:seed RAILS_ENV=production" app
RUN su -c "cd /home/app/openproject && bundle exec rake assets:precompile" app

# Remove the logs directory. We will link it outside the docker
RUN rm -R /home/app/openproject/log

# id_rsa.pub must first be copied from ~/.ssh/id_rsa.pub
# If you do not have this file, you should run ssh-keygen
# Without this step you will be unable to identify when connecting via ssh
ADD id_rsa.pub /tmp/your_key.pub
RUN cat /tmp/your_key.pub >> /root/.ssh/authorized_keys && rm -f /tmp/your_key.pub

# Regenerate SSH host keys. baseimage-docker does not contain any, so you
# have to do that yourself. You may also comment out this instruction; the
# init system will auto-generate one during boot.
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

# Add your nginx configuration, replacing the default
RUN rm -f /etc/nginx/sites-available/default
ADD files/nginx-default /etc/nginx/sites-available/default

# Enable nginx
RUN rm -f /etc/service/nginx/down

# Use Phusion docker's init system.
# It is highly recommended you use only it
CMD ["/sbin/my_init"]

# docker build -t jgigov/openproject:3.0 .
# docker run -v /var/log/openproject:/home/app/openproject/log -v /var/local/openproject:/home/app/openproject/files --name proj_server --hostname ProjServ -d jgigov/openproject:3.0
