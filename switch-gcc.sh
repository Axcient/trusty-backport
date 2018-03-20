#!/bin/sh
set -e
set -x

update() {
    local bin=$1
    local version=$2
    update-alternatives \
        --install /usr/bin/$bin $bin /usr/bin/$bin-$version 60
    # If we ever want to change later it will look something like..
    #update-alternatives \
    #  --install /usr/bin/$bin $bin /usr/bin/$bin-4.8 60
}

update_with_slave() {
    local bin=$1
    local slave=$2
    local version=$3
    update-alternatives \
        --install /usr/bin/$bin $bin /usr/bin/$bin-$version 60 \
        --slave /usr/bin/$slave $slave /usr/bin/$slave-$version
    #update-alternatives \
    #  --install /usr/bin/$bin $bin /usr/bin/$bin-4.8 60 \
    #  --slave /usr/bin/$slave $slave /usr/bin/$slave-4.8
}

switch_gcc() {
    local version=$1
    update_with_slave gcc g++ $version
    update_with_slave x86_64-linux-gnu-gcc x86_64-linux-gnu-g++ $version
    update gcc-ar $version
    update gcc-nm $version
    update gcc-ranlib $version
    update gcov $version
    update x86_64-linux-gnu-gcc-nm $version
    update x86_64-linux-gnu-gcc-ranlib $version
    update x86_64-linux-gnu-gcc-ar $version
    update x86_64-linux-gnu-gcov $version
}

newversion=$1
switch_gcc $newversion
