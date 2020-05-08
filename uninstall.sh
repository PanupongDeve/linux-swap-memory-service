sudo systemctl stop swap-memory.service

sudo systemctl disable swap-memory.service

sudo systemctl status swap-memory.service 

sudo rm -rf /etc/systemd/system/default.target.wants/swap-memory.service


sudo rm -rf /etc/systemd/system/swap-memory.service

sudo rm -rf /usr/local/bin/swap-memory.sh
