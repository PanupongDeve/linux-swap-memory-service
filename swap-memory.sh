#!/bin/bash
sudo swapoff -a
echo "swap memmory to $1GB plase waiting..."
sudo fallocate -l $1G /swapfile
sudo chmod 0600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
grep SwapTotal /proc/meminfo