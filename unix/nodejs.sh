#!/bin/bash

echo '[info] Install some package for developing Node js'

apt-get update
apt-get install -y nodejs npm
ln -s $(which nodejs) /usr/bin/node
apt-get autoremove
apt-get autoclean
npm install express -g
npm install express-generator -g

echo $(node -v)
echo $(npm -v)
