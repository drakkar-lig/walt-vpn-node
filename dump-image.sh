#!/bin/sh

SDCARD_IMG=/root/sdcard.img

if [ "$1" = "" ]
then
    echo "Usage: $0 <walt-vpn-entrypoint>" >&2
    exit 1
fi

# we use mcopy to write a file walt-vpn.conf on the first partition
# of the SD card image.
# services running from the root partition are configured to lookup this
# file to get the entrypoint.

walt_vpn_entrypoint="$1"
echo "WALT_VPN_ENTRYPOINT='$walt_vpn_entrypoint'" > walt-vpn.conf

start_sector=$(partx --noheadings --nr 1 -o START --show $SDCARD_IMG)
start_byte=$((start_sector*512))

mcopy -D o -i sdcard.img@@$start_byte walt-vpn.conf ::walt-vpn.conf

cat sdcard.img
