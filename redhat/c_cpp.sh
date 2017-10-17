#!/bin/bash

echo '[info] Install some package for developing c/c++'


yum update
# C/C++ environment
yum install -y build-essential gcc g++ cmake make gdb
yum autoremove
yum autoclean