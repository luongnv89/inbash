#!/bin/bash

echo '[info] Install some package for developing c/c++'


apt-get update
# C/C++ environment
apt-get install -y build-essential gcc g++ cmake make gdb
apt-get autoremove
apt-get autoclean