#!/bin/bash

# Pre-requisities
echo 'Pre-requisities'
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install -y zip unzip
sudo apt-get autoremove
sudo apt-get autoclean
sudo ldconfig

echo 'Installing Apache'
sudo apt-get install -y apache2

echo 'Installing PHP5'
sudo apt-get install -y php5 libapache2-mod-php5

echo 'Installing Laravel'
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

mkdir -p /var/www
mkdir -p /var/www/html
composer create-project laravel/laravel hello_world --prefer-dist

echo 'Configuring Apache'
sudo chgrp -R www-data /var/www/html/hello_world
cd /var/www/html/hello_world
cp .env.example .env
php artisan key:generate
php artisan config:clear
chmod 777 -R storage
chmod chmod -R 777 bootstrap/cache
sudo cp /home/montimage/inbash/unix/laravel.conf /etc/apache2/sites-available

echo 'Activating Configure Apache'
cd /etc/apache2/sites-available
sudo a2dissite 000-default.conf
sudo a2ensite laravel.conf
sudo a2enmod rewrite
sudo service apache2 restart


