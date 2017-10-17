#!/bin/bash
cp show_ip /etc/network/if-up.d/
chmod +x /etc/network/if-up.d/show_ip
#create a copy to the other folder
ln -s /etc/network/if-up.d/show_ip /etc/network/if-post-down.d/
/etc/network/if-up.d/show_ip