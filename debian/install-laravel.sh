#!/bin/bash

# Pre-requisities
echo '----> Pre-requisities'
sudo apt-get update -y 
sudo apt-get upgrade -y
sudo apt-get install -y zip unzip
sudo apt-get autoremove
sudo apt-get autoclean
sudo ldconfig

echo '----> Installing Apache'
sudo apt-get install -y apache2

echo '----> Installing PHP5'
sudo apt-get install -y php5 libapache2-mod-php5

echo '----> Installing Laravel'
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

mkdir -p /var/www
mkdir -p /var/www/html
cd /var/www/html
<<<<<<< HEAD:debian/install-laravel.sh
composer create-project laravel/laravel hello_world --prefer-dist
=======
composer create-project laravel/laravel helloworld --prefer-dist
>>>>>>> 703bddb725dc6b77ec5f6fa0beefed7738f9080b:unix/install-laravel.sh

echo '----> Configuring Apache'
sudo chgrp -R www-data /var/www/html/helloworld
cd /var/www/html/helloworld
cp .env.example .env
php artisan key:generate
php artisan config:clear
chmod 777 -R storage
chmod -R 777 bootstrap/cache
<<<<<<< HEAD:debian/install-laravel.sh
sudo cp /home/montimage/inbash/unix/laravel.conf /etc/apache2/sites-available

echo 'Activating Configure Apache'
cd /etc/apache2/sites-available
sudo a2dissite 000-default.conf
sudo a2ensite laravel.conf
sudo a2enmod rewrite
sudo service apache2 restart
=======

# sudo cp /home/montimage/inbash/unix/laravel.conf /etc/apache2/sites-available

# echo '----> Activating Configure Apache'
# cd /etc/apache2/sites-available
# sudo a2dissite 000-default.conf
# sudo a2ensite laravel.conf
# sudo a2enmod rewrite
# sudo service apache2 restart
>>>>>>> 703bddb725dc6b77ec5f6fa0beefed7738f9080b:unix/install-laravel.sh


