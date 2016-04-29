#!/bin/bash
# Valgrind is a debugging tool for checking memory leak, data race in c/c++ program
# More information: http://valgrind.org/docs/manual/QuickStart.html

echo '[info] Install valgrind for checking memory in c/c++ project'


sudo apt-get update
sudo apt-get install -y valgrind
sudo apt-get autoremove
sudo apt-get autoclean

echo $(valgrind --version)