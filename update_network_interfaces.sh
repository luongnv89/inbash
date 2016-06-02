#!/bin/bash
# Replace default interfaces file with new interfaces file. To update more network interface, please look at the file : interfaces
sudo cp interfaces /etc/network/interfaces

# Bring eth1 up
sudo ifup eth1
sudo /sbin/ifconfig

# Bring more network interface up here