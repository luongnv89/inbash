#!/bin/bash
# Install Mongodb extension for PHP on Mac OSX

echo '[inbash] Installing brew'
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
sudo chown $(whoiam) /usr/local
brew install openssl
brew install pcre
brew install php70-mongodb

echo '[inbash] Install pecl'

curl -O http://pear.php.net/go-pear.phar

sudo php -d detect_unicode=0 go-pear.phar

echo '[inbash] Install mongodb extension'
pecl download mongodb
tar zxvf mongodb*.tgz
cd mongodb*
phpize
./configure --with-openssl-dir=/usr/local/opt/openssl
make
mkdir -p /usr/local/lib/php/
mkdir -p /usr/local/lib/php/extensions
sudo make EXTENSION_DIR='/usr/local/lib/php/extensions' install

echo '[inbash] update php.ini file'
sudo cp /private/etc/php.ini.default /private/etc/php.ini
echo 'extension=/usr/local/lib/php/extensions/mongodb.so' >> /private/etc/php.ini

echo '[inbash] Restart apachectl'

sudo apachectl restart

echo '[inbash] Check mongodb driver in http://localhost/index.php'
