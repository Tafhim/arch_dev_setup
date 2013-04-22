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
 
echo "Installing packages"
pacman -Syy
pacman -S --needed vim dnsmasq apache php php-pear php-sqlite php-curl imap php-intl mysql php-apache php-mcrypt phpmyadmin git openssh nodejs curl zlib base-devel sqlite3 openssl libyaml
# From AUR = drush
rm -rf drush
curl -o $IDIR/drush.tar.gz https://aur.archlinux.org/packages/dr/drush/drush.tar.gz
tar xf $IDIR/drush.tar.gz
cd $IDIR/drush
makepkg --asroot
pacman -U --needed $IDIR/drush/drush*.tar.xz
cd $IDIR
 
echo "Enabling MySQL"
systemctl enable mysqld
echo "Starting MySQL + Configuration, God help ya!"
systemctl start mysqld
/usr/bin/mysql_secure_installation
 
 
echo "Creating workspace directories"
mkdir -p $USER_HOME/workspace/php/projects
mkdir -p $USER_HOME/workspace/php/www
 
echo "Applying ownership for $USER"
chown -R $USER:users $USER_HOME/workspace
chmod o+x $USER_HOME/
chmod 0755 $USER_HOME/
chmod -R o+x $USER_HOME/workspace/
 
echo "Configuring dnsmasq"
echo " added listen-address=127.0.0.1"
echo " added address=/.dev/127.0.0.1"
cp -f $IDIR/etc/dnsmasq.conf /etc/dnsmasq.conf
echo "Generating OpenSSL certificate"
cd /etc/httpd/conf
openssl genrsa -out server.key 2048
chmod 600 server.key
openssl req -new -key server.key -out server.csr
openssl x509 -req -days 365 -in server.csr -signkey server.key -out server.crt
cd $USER_HOME
echo "Configuring Apache"
echo " /srv/http turned off, / being used for <Directory>"
sudo sed -e "s#__USER_HOME__#$USER_HOME#" $IDIR/etc/httpd/conf/extra/httpd-vhosts.conf > /etc/httpd/conf/extra/httpd-vhosts.conf
cp -f $IDIR/etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf
sed -i -e 's/dns=dnsmasq/#dns=dnsmasq/g' /etc/NetworkManager/NetworkManager.conf
# Specifically for NetworkManager
cp -f $IDIR/etc/NetworkManager/dispatcher.d/localhost-prepend /etc/NetworkManager/dispatcher.d/localhost-prepend
chmod +x /etc/NetworkManager/dispatcher.d/localhost-prepend
systemctl enable dnsmasq
systemctl stop dnsmasq
systemctl start dnsmasq
#echo "Testing dnsmasq"
#ping -c 1 -w 5 oompooseebooleessoorvoorees.dev &>/dev/null
#if [ $? -ne 0 ] ; then
# echo "dnsmasq not working, check your resolv.conf, 'nameserver 127.0.0.1' has to be first, terminating"
# exit 1
#else
# echo "No problems detected, dnsmasq is up and running"
#fi
echo "UseDNS no" >> /etc/ssh/sshd_config
echo "Adding Apache to start up"
systemctl enable httpd
cd $IDIR
echo "Configuring phpmyadmin"
rm -r /srv/http/phpMyAdmin
cp /etc/webapps/phpmyadmin/apache.example.conf /etc/httpd/conf/extra/httpd-phpmyadmin.conf
cp -f $IDIR/etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf
sed -i "s/deny/allow/g" /etc/webapps/phpmyadmin/.htaccess
sed -i "s/;extension=mysqli.so/extension=mysqli.so/g" /etc/php/php.ini
sed -i "s/;extension=mcrypt.so/extension=mcrypt.so/g" /etc/php/php.ini
 
echo "Reboot the system!!"
#reboot