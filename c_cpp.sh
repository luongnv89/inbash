#!/bin/bash

echo '[info] Install some package for developing c/c++'


sudo apt-get update
# C/C++ environment
sudo apt-get install -y build-essential gcc g++ cmake make gdb
sudo apt-get autoremove
sudo apt-get autoclean