#!/bin/sh

yum -y install patch
cp -rp /vagrant /usr/local/src/sentry
cd /usr/local/src/sentry
sh setup_sentry.sh
