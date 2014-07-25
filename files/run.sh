#!/bin/sh
export RAILS_ENV=production
cd /root/openproject
bundle exec rails server>>/dev/null
