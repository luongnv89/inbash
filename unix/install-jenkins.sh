#!/bin/bash

# Update system
sudo apt-get update -y

# Install java
# sudo add-apt-repository ppa:webupd8team/java -y
# sudo apt-get update -y
# sudo apt-get install oracle-java8-installer

sudo apt-get install -y openjdk-8-jre
sudo apt-get install -y openjdk-8-jdk


# Install jenkins
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo echo 'deb https://pkg.jenkins.io/debian-stable binary/' >> /etc/apt/sources.list
sudo apt-get update
sudo apt-get install jenkins

# Alternative
# wget http://mirrors.jenkins.io/war-stable/latest/jenkins.war
# java -jar jenkins.war