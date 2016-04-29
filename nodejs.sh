#!/bin/bash

echo '[info] Install some package for developing Node js'

sudo apt-get update
sudo apt-get install -y nodejs npm
sudo ln -s $(which nodejs) /usr/bin/node
sudo apt-get autoremove
sudo apt-get autoclean
sudo npm install express -g
sudo npm install express-generator -g
