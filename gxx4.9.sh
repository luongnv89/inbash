#!/bin/bash
# Install gcc-4.9 and g++-4.9

echo '[info] Install gcc/g++ version 4.9'


sudo apt-get update

sudo apt-get install build-essential
sudo add-apt-repository ppa:ubuntu-toolchain-r/test
sudo apt-get update
sudo apt-get install -y gcc-4.9 g++-4.9 cpp-4.9
cd /usr/bin
sudo rm gcc g++ cpp
sudo ln -s gcc-4.9 gcc
sudo ln -s g++-4.9 g++
sudo ln -s cpp-4.9 cpp

echo $(gcc -v)