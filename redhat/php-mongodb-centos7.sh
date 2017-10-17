#!/bin/bash
# Install php, mongodb and http server on centos7
#
#

echo '[inbash] Install HTTP deamon ...'
sudo yum install -y httpd
sudo systemctl start httpd.service
sudo systemctl enable httpd.service
sudo systemctl restart httpd.service

echo '[inbash] Open port 80 for TCP/UDP traffic ...'
sudo firewall-cmd --zone=dmz --add-port=80/tcp --permanent
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --zone=dmz --add-port=80/udp --permanent
sudo firewall-cmd --zone=public --add-port=80/udp --permanent
sudo firewall-cmd --reload

echo '[inbash] Install php ...'
sudo yum install -y php gcc php-pear php-devel openssl-devel
sudo pecl install mongo

echo '[inbash] You need to update php.ini. Command: '
echo '[inbash] Add "extension=mongo.so" into the file: sudo vi /etc/php.ini'
echo '[inbash] Reload server: sudo service httpd restart'