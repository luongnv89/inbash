#!/bin/bash

echo '---> [info] Install MYSQL'

yum update
yum install -y php5-mysql mysql-server
