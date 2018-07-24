#!/bin/sh

set -e

export PATH=/usr/sbin:/sbin:$PATH

cat > /etc/apache2/conf-available/dyn-vhost.conf <<EOF
UseCanonicalName Off

RemoteIPHeader X-Forwarded-For
RemoteIPInternalProxy 172.31.0.0/16 10.180.21.0/24 127.0.0.0/8

LogFormat "%V %a %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\" %T %D" vcommon
CustomLog "| /usr/bin/rotatelogs /srv/${WP_ENV}/logs/access_log.$(hostname).%Y%m%d 86400" vcommon
CustomLog "/dev/stdout" vcommon

ErrorLog "| /usr/bin/rotatelogs /srv/${WP_ENV}/logs/error_log.$(hostname).%Y%m%d 86400"

VirtualDocumentRoot "/srv/${WP_ENV}/%0/htdocs"

<VirtualHost *:8443>
  SSLEngine on
  SSLCertificateFile "/etc/apache2/ssl/server.cert"
  SSLCertificateKeyFile "/etc/apache2/ssl/server.key"
</VirtualHost>
EOF

/bin/mkdir -p /srv/${WP_ENV}/logs
/bin/mkdir -p /srv/${WP_ENV}/jahia2wp
/bin/chown www-data: /srv/${WP_ENV}
/bin/chown www-data: /srv/${WP_ENV}/logs
/bin/chown www-data: /srv/${WP_ENV}/jahia2wp

/bin/mkdir -p /etc/apache2/ssl
/usr/bin/openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:4096 -keyout /etc/apache2/ssl/server.key -out /etc/apache2/ssl/server.cert -subj "/C=CH/ST=Vaud/L=Lausanne/O=Ecole Polytechnique Federale de Lausanne (EPFL)/CN=*.epfl.ch"

/bin/mkdir -p /var/www/html/probes/ready
echo "OK" > /var/www/html/probes/ready/index.html

set -x
# Change max upload size for http requests
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 300M/" /etc/php/7.1/apache2/php.ini
sed -i "s/post_max_size = .*/post_max_size = 300M/" /etc/php/7.1/apache2/php.ini
# Change max upload size for CLI requests
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 300M/" /etc/php/7.1/cli/php.ini
sed -i "s/post_max_size = .*/post_max_size = 300M/" /etc/php/7.1/cli/php.ini

a2dissite 000-default
a2enmod ssl
a2enmod rewrite
a2enmod vhost_alias
a2enmod status
a2enmod remoteip
a2enconf dyn-vhost


if [ -d "/run/secrets/xdebug" ]; then
    a2enmod xdebug
else
    a2dismod xdebug
fi

exec apache2ctl -DFOREGROUND
