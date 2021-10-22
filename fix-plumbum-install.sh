#!/bin/bash

# plumbum package uses setup.cfg and has just a call to setup() with no
# arguments in setup.py.
# no version is defined in any of these two files.
# this causes setuptools to consider plumbum version is 0.0.0.
# below we edit the setup.cfg file to let setuptools know the version.
cd dl/python-plumbum
version=$(ls plumbum-*.tar.gz | sed -e 's/plumbum-\(.*\).tar.gz/\1/')
tar xfz plumbum-$version.tar.gz
cd plumbum-$version
sed -i -e "s/^\(name.*\)$/\1\nversion = $version/" setup.cfg
cd ..
tar cfz plumbum-$version.tar.gz plumbum-$version
rm -rf plumbum-$version
