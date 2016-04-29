#!/bin/bash
sudo cp show_ip /etc/network/if-up.d/
sudo chmod +x /etc/network/if-up.d/show_ip
#create a copy to the other folder
sudo ln -s /etc/network/if-up.d/show_ip /etc/network/if-post-down.d/
sudo /etc/network/if-up.d/show_ip