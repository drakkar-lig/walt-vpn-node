#!/bin/sh
set -e

declare_package_after()
{
    ref_package="$1"
    new_package="$2"
    sed -i -e "s/^\(.*source.*python-\)\($ref_package\)\(.*\)$/\1\2\3\n\1$new_package\3/" package/Config.in
}

# allow target glibc to work with an older kernel
# (needed to be able to run walt-*-setup as a qemu-based chrooted command later
# in the build)
sed -i -e 's/enable-kernel=.* \\$/enable-kernel=4.19 \\/' ./package/glibc/glibc.mk

# add dependencies
utils/scanpypi plumbum

for dl_file in dl/walt-*.tar.gz
do
    # parse package name and version
    set -- $(echo $dl_file | sed -e 's/^...\(.*\)-\([^-]*\).tar.gz/\1 \2/')
    walt_package="$1"
    version="$2"

    # move to package subdir
    python_package="python-$walt_package"
    mkdir -p "dl/$python_package"
    mv $dl_file "dl/$python_package/"

    # add package to buildroot
    utils/scanpylocal "dl/$python_package/$walt_package-$version.tar.gz"

    # let the build system know it is downloaded
    mkdir -p "output/build/$python_package-$version"
    touch "output/build/$python_package-$version/.stamp_downloaded"
done

# declare packages in buildroot config system
declare_package_after pluggy plumbum
declare_package_after visitor walt-common
declare_package_after walt-common walt-virtual
declare_package_after walt-virtual walt-vpn
