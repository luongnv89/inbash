#!/bin/bash
# Get started with scapy: http://www.secdev.org/projects/scapy/demo.html
apt-get update
apt-get install -y software-properties-common build-essential tcpdump gnuplot
apt-get install -y python python-pip python-numpy python-pyx python-crypto python-gnuplot
pip install scapy
