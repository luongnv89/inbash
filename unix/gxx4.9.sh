#!/bin/bash
# Install gcc-4.9 and g++-4.9

echo '[info] Install gcc/g++ version 4.9'


apt-get update
apt-get install -y software-properties-common
apt-get install build-essential
add-apt-repository ppa:ubuntu-toolchain-r/test
apt-get update
apt-get install -y gcc-4.9 g++-4.9 cpp-4.9
cd /usr/bin
rm gcc g++ cpp
ln -s gcc-4.9 gcc
ln -s g++-4.9 g++
ln -s cpp-4.9 cpp

echo $(gcc -v)