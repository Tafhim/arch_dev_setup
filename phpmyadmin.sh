#!/bin/sh

if [ "$(id -u)" != "0" ]; then
echo "This script must be run as root" 1>&2
exit 1
fi

if [ -z "$1" ]
then
echo "Usage: $0 user_name"
exit 1
fi

USER=$1
USER_HOME=/home/$USER
IDIR=$USER_HOME/dev_server_installer

cd $IDIR

pacman -Syy
pacman -S phpmyadmin php-mcrypt

echo "Configuring phpmyadmin"
rm -r /srv/http/phpMyAdmin
cp /etc/webapps/phpmyadmin/apache.example.conf /etc/httpd/conf/extra/httpd-phpmyadmin.conf
cp -f $IDIR/etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf
sed -i "s/deny/allow/g" /etc/webapps/phpmyadmin/.htaccess
sed -i "s/;extension=mysqli.so/extension=mysqli.so/g" /etc/php/php.ini
sed -i "s/;extension=mcrypt.so/extension=mcrypt.so/g" /etc/php/php.ini

echo "Reboot the system!!"
#reboot


