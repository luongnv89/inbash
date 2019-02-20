#!/bin/bash
# Install share folder on virtualbox virtual machine
# 1. Error:
# VirtualBox: mount.vboxsf: mounting failed with the error: No such device
# Solution:
# $ sudo modprobe -a vboxguest vboxsf vboxvideo
# 2. Error:
# virtualbox mount: unknown filesystem type ‘vboxsf’
# Solution:
# $ sudo apt-get install virtualbox-guest-dkms

mount -t vboxsf -o uid=$(id -u),gid=$(id -g) workspace /home/montimage/workspace
