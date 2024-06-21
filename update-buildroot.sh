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
sed -i -e "s/^\(PYTHON_PLUMBUM_SETUP_TYPE =\) unknown/\1 pep517/" \
    package/python-plumbum/python-plumbum.mk
sed -i '/^PYTHON_PLUMBUM_SETUP_TYPE/a PYTHON_PLUMBUM_DEPENDENCIES = host-python-hatchling host-python-hatch-vcs' \
    package/python-plumbum/python-plumbum.mk

for dl_file in dl/walt*.tar.gz
do
    # parse package name and version
    set -- $(echo $dl_file | sed -e 's/^...\(.*\)-\([^-]*\).tar.gz/\1 \2/' | tr "_" "-")
    walt_package="$1"
    version="$2"

    # move to package subdir
    python_package="python-$walt_package"
    mkdir -p "dl/$python_package"
    mv $dl_file "dl/$python_package/"
    bn_dl_file=$(basename $dl_file)

    # add package to buildroot
    utils/scanpylocal "dl/$python_package/$bn_dl_file"

    # let the build system know it is downloaded
    mkdir -p "output/build/$python_package-$version"
    touch "output/build/$python_package-$version/.stamp_downloaded"
done

# declare packages in buildroot config system
declare_package_after pluggy plumbum
declare_package_after visitor walt-common
declare_package_after walt-common walt-virtual
declare_package_after walt-virtual walt-vpn
