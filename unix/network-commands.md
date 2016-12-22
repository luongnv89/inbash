# NETWORK USEFUL COMMANDS

Some network useful commands

* Bring up an interface: `sudo ifconfig eth3 up`

* Take down an interface: `sudo ifconfig eth3 down`

* Enable promisc mode: `sudo ifconfig eth3 promisc`

* Disnable promisc mode: `sudo ifconfig eth3 -promisc`

* Show statistic: `netstat -i`

* Show all available network devices (event they are off): `cat /proc/net/dev`

* Check connection status of an interface: `sudo ethtool eth3 | grep "Link detected"`