#!/bin/bash
# Get started with scapy: http://www.secdev.org/projects/scapy/demo.html
yum update
yum install -y software-properties-common build-essential tcpdump gnuplot
yum install -y python python-pip python-numpy python-pyx python-crypto python-gnuplot
pip install scapy
# support for parsing HTTP in scapy: pip install scapy-http
