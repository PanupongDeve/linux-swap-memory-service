#!/bin/bash
sudo swapoff -a
echo "swap memmory to $1GB plase waiting..."
sudo dd if=/dev/zero of=/swapfile bs=1G count=$1
sudo mkswap /swapfile
sudo swapon /swapfile
grep SwapTotal /proc/meminfo