#!/bin/bash
# Install tomahawk, a tool for replay network traffic. More information: http://tomahawk.sourceforge.net/
# It works best on debian 32bit
echo "[info] Tomahawk installation"
cd /usr/src
echo "[info] Installing dependencies:"
apt-get install -y ssh gcc flex bison make
echo "[info] Installing libpcap"
wget http://www.packet-foo.com/tomahawk/libpcap-0.8.1.tar.gz
tar xzf libpcap-0.8.1.tar.gz
cd libpcap-0.8.1/
./configure
make
make install
cd ..
echo "[info] Installing libnet"
wget http://www.packet-foo.com/tomahawk/libnet-1.0.2a.tar.gz
tar xzf libnet-1.0.2a.tar.gz
cd Libnet-1.0.2a
./configure
make
make install
cd ..
echo "[info] Installing tomahawk"
wget http://prdownloads.sourceforge.net/tomahawk/tomahawk1.1.tar.gz
tar xzf tomahawk1.1.tar.gz
cd tomahawk1.1
make
make install
cd ..

echo "[info] Cleaning.."
rm -rf libpcap-0.8.1.tar.gz libnet-1.0.2a.tar.gz tomahawk1.1.tar.gz
echo "[info] Tomahawk has installed, now we can test..."