# Setup Sentry with MySQL and Redis as Queue/Buffer/Cache

# Install mysql-server
## it also switchable to MySQL 5.5/5.6 or PostgreSQL 9.2 as you need.
yum -y install mysql-server

# Install mysql-devel to `easy_install mysql-python` in virtualenv
yum -y install mysql-devel

# Install epel yum repository for python-virtualenv and redis
yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

# Install Redis to enable buffer/queue/cache for Sentry
yum -y install redis

# Install Sentry dependencies
yum -y install gcc python-setuptools python-devel python-virtualenv

# Create database
service mysqld start
mysql -uroot -e "create database sentry;"
mysql -uroot -e "GRANT ALL PRIVILEGES ON sentry.* TO sentry@localhost IDENTIFIED BY 'sentry';"
mysql -uroot -e "GRANT ALL PRIVILEGES ON sentry.* TO sentry@'%' IDENTIFIED BY 'sentry';"
mysql -uroot -e "FLUSH PRIVILEGES;"

# Create Sentry home directory, user and group
virtualenv /var/sentry/
source /var/sentry/bin/activate
groupadd sentry
useradd -M -g sentry -d /var/sentry/ sentry
chown -R sentry:sentry /var/sentry/

# Setup Sentry and Redis libraries
su sentry -c "(
  easy_install --quiet -UZ mysql-python sentry
  easy_install --quiet -UZ pip
  pip install --quiet redis django-redis-cache hiredis nydus
)"

# Initialize configuration
sentry init /etc/sentry.conf.py
patch -p1 /etc/sentry.conf.py < /usr/local/src/sentry/sentry.conf.py.patch
service redis start

# Setup admin user
export SENTRY_CONF=/etc/sentry.conf.py
su sentry -c "/var/sentry/bin/sentry --config=/etc/sentry.conf.py upgrade"
python -c "from sentry.utils.runner import configure; configure(); from django.db import DEFAULT_DB_ALIAS as database; from sentry.models import User; User.objects.db_manager(database).create_superuser('admin', 'admin@example.com', 'admin')" executable=/bin/bash chdir=/var/sentry

# Run Sentry as a service
yum -y install supervisor --enablerepo=epel
cat /usr/local/src/sentry/supervisord_sentry.conf >> /etc/supervisord.conf
service supervisord start
/usr/bin/supervisorctl status

# Configure autostart
chkconfig redis on
chkconfig mysqld on
chkconfig supervisord on

# Terminate daemon
service supervisord stop
service redis stop
service mysqld stop
