#!/bin/bash

echo '[info] Install some package for developing Node js'

apt-get update
# Using Ubuntu
curl -sL https://deb.nodesource.com/setup_11.x | sudo -E bash -
sudo apt-get install -y nodejs

echo $(node -v)
echo $(npm -v)
