#!/bin/bash

# Update system
sudo apt-get update -y

# Install java
sudo add-apt-repository ppa:webupd8team/java -y
sudo apt-get update -y
sudo apt-get install oracle-java8-installer

# Install jenkins
wget http://mirrors.jenkins.io/war-stable/latest/jenkins.war
java -jar jenkins.war