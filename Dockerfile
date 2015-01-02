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
FROM phusion/passenger-customizable:latest

MAINTAINER OpenProject Foundation (opf), info@openproject.org

ENV DEBIAN_FRONTEND noninteractive

# Get repositories
RUN apt-get update

RUN /build/utilities.sh && \
/build/ruby2.1.sh && \
/build/nodejs.sh && \
/build/memcached.sh && \
rm -f /etc/service/nginx/down && \
rm -f /etc/service/memcached/down && \
npm -g install bower && \
rm -f /etc/nginx/sites-available/default


# Install most missing things we need
# To minimize your image you should remove database packages you don't need
RUN apt-get install curl zlib1g-dev libssl-dev libreadline-dev \
libyaml-dev libsqlite3-dev sqlite3 libmysqlclient-dev libpq-dev libxml2-dev libxslt1-dev libcurl4-openssl-dev \
python-software-properties memcached libgdbm-dev libncurses5-dev automake libtool bison libffi-dev && \
apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


USER app
WORKDIR ~

RUN git clone https://github.com/opf/openproject.git -b stable --depth 1

WORKDIR openproject
RUN bundle install && \
npm install && \
bower install

# You must edit the configuration and database files before adding them
ADD files/configuration.yml config/configuration.yml 
ADD files/database.yml config/database.yml 
ADD files/nginx-default /etc/nginx/sites-available/default

# Default installation steps as described in OpenProject's wiki

RUN bundle exec rake db:create:all && \
bundle exec rake generate_secret_token && \
RAILS_ENV="production" bundle exec rake db:migrate && \
RAILS_ENV="production" bundle exec rake db:seed && \
RAILS_ENV="production" bundle exec rake assets:precompile 

# Use Phusion docker's init system.
# It is highly recommended you use only it
CMD ["/sbin/my_init"]

# docker build -t jgigov/openproject:3.0 .
# docker run -v /var/log/openproject:/home/app/openproject/log -v /var/local/openproject:/home/app/openproject/files --name proj_server --hostname ProjServ -d jgigov/openproject:3.0
