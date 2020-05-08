
sudo cp swap-memory.service /etc/systemd/system/

sudo chmod 664 /etc/systemd/system/swap-memory.service

sudo cp swap-memory.sh /usr/local/bin/

sudo chmod +x /usr/local/bin/swap-memory.sh

sudo systemctl daemon-reload

sudo systemctl enable swap-memory.service 

sudo systemctl status swap-memory.service 