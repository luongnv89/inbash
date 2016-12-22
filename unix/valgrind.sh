#!/bin/bash
# Valgrind is a debugging tool for checking memory leak, data race in c/c++ program
# More information: http://valgrind.org/docs/manual/QuickStart.html

echo '[info] Install valgrind for checking memory in c/c++ project'


apt-get update
apt-get install -y valgrind
apt-get autoremove
apt-get autoclean

echo $(valgrind --version)