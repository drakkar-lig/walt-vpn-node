#!/bin/sh
set -e

# install walt-common and walt-virtual
cd /root/walt-python-packages
dev/info-updater.py
cd common && python3 -m pip install . && cd ..
cd virtual && python3 -m pip install . && cd ..

# run walt-virtual-setup
walt-virtual-setup --type VPN_CLIENT --init-system BUSYBOX
