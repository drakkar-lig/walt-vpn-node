#!/bin/sh

# allow target glibc to work with an older kernel
# (needed to be able to run walt-virtual-setup as a qemu-based chrooted command later
# in the build)
sed -i -e 's/enable-kernel=.* \\$/enable-kernel=4.4 \\/' ./package/glibc/glibc.mk
