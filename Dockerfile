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
RUN apt-get -y install libxml2-dev libxslt-dev g++ libpq-dev sqlite3 ruby-sqlite3 libsqlite3-dev ruby-mysql2 libmysql++-dev && apt-get clean

# Install a the bundler needed
RUN gem install bundler --version '>=1.5.1'

# Get stable version of openproject from the repository into root's home directory
RUN cd /root && git clone https://github.com/opf/openproject.git -b stable

# This build by default is PostgreSQL enabled.
# Alter the next line as appropriate for your database setup
RUN cd /root/openproject && bundle install --without mysql mysql2 sqlite development test rmagick

# You must edit the configuration and database files before adding them
ADD files/configuration.yml /root/openproject/config/configuration.yml 
ADD files/database.yml /root/openproject/config/database.yml 

# This replacement production.rb has enabled static resources.
# The default production version would expect them to be on another server
# and your build would be broken
RUN rm /root/openproject/config/environments/production.rb
ADD files/production.rb /root/openproject/config/environments/production.rb

#ADD files/Gemfile.plugins /root/openproject/Gemfile.plugins

# The next line must be uncommented to use sqlite storage outside the container
#RUN mkdir /root/openproject/db/sqlite

# Default installation steps as described in OpenProject's wiki
RUN cd /root/openproject && bundle exec rake generate_secret_token
RUN cd /root/openproject && bundle exec rake db:create:all
#RUN touch /root/openproject/db/sqlite/production.db
RUN cd /root/openproject && bundle exec rake db:migrate db:seed RAILS_ENV=production
RUN cd /root/openproject && bundle exec rake assets:precompile

# These directories will be linked outside the docker for easy access and persistent storage
RUN rm -R /root/openproject/log
RUN rm -R /root/openproject/files

# Regenerate SSH host keys. baseimage-docker does not contain any, so you
# have to do that yourself. You may also comment out this instruction; the
# init system will auto-generate one during boot.
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

# id_rsa.pub must first be copied from ~/.ssh/id_rsa.pub
# If you do not have this file, you should run ssh-keygen
# Without this step you will be unable to identify when connecting via ssh
ADD id_rsa.pub /tmp/your_key.pub
RUN cat /tmp/your_key.pub >> /root/.ssh/authorized_keys && rm -f /tmp/your_key.pub

# The default service port 3000 can be changed in the file /root/openproject/config/settings.yml
EXPOSE 22
EXPOSE 3000

# Add the startup script that Phusion Passenger will run
RUN mkdir /etc/service/openproject
ADD files/run.sh /etc/service/openproject/run

# Minimize the image by removing apt repos.
RUN rm -r /var/cache/apt /var/lib/apt/lists

# Minimize the image by removing apt repos.
RUN rm -r /var/cache/apt /var/lib/apt/lists
# Using Phusion docker image's init system.
# It is highly recommended you use only it
CMD ["/sbin/my_init"]

# To build and run use the following commands in the directory
# ONLY AFTER(!!!) you have made and copied your id_rsa.pub file
# in this directory and created /var/log/openproject and /var/local/openproject
# or whatever equivalents you wish to replace them with.
# docker build -t openproject:3.0.8 .
# docker run -v /var/log/openproject:/root/openproject/log -v /var/local/openproject/files:/root/openproject/files --name proj_server --hostname ProjServ -d openproject:3.0.8

