#!/bin/bash
# Valgrind is a debugging tool for checking memory leak, data race in c/c++ program
# More information: http://valgrind.org/docs/manual/QuickStart.html

echo '[info] Install valgrind for checking memory in c/c++ project'


yum update
yum install -y valgrind
yum autoremove
yum autoclean

echo $(valgrind --version)