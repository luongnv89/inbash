#!/bin/bash

echo '[info] Install some package for developing Node js'

yum update
yum install -y nodejs npm
ln -s $(which nodejs) /usr/bin/node
yum autoremove
yum autoclean
npm install express -g
npm install express-generator -g

echo $(node -v)
echo $(npm -v)
