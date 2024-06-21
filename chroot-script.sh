#!/bin/sh
set -e

export LOGNAME="root"

# create missing ssh host keys
# ssh service will try to do it and fail otherwise, because the filesystem
# is kept read-only.
/usr/bin/ssh-keygen -A

# instruct the OS to mount rootfs read-only
sed -i -e 's/\([[:space:]]\/[[:space:]].*[[:space:]]\)rw,/\1ro,/' /etc/fstab

# run setup commands
walt-virtual-setup-node --init-system BUSYBOX
walt-vpn-setup --type VPN_CLIENT --init-system BUSYBOX
