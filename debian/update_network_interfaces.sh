#!/bin/bash
# Replace default interfaces file with new interfaces file. To update more network interface, please look at the file : interfaces
cp interfaces /etc/network/interfaces

# Bring eth1 up
ifup eth1
/sbin/ifconfig

# Bring more network interface up here