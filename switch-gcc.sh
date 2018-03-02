#!/bin/sh
set -e
set -x

newversion=$1

update() {
    bin=$1
    update-alternatives \
        --install /usr/bin/$bin $bin /usr/bin/$bin-$newversion 60
    # If we ever want to change later it will look something like..
    #update-alternatives \
    #  --install /usr/bin/$bin $bin /usr/bin/$bin-4.8 60
}

update_with_slave() {
    bin=$1
    slave=$2
    update-alternatives \
        --install /usr/bin/$bin $bin /usr/bin/$bin-$newversion 60 \
        --slave /usr/bin/$slave $slave /usr/bin/$slave-$newversion
    #update-alternatives \
    #  --install /usr/bin/$bin $bin /usr/bin/$bin-4.8 60 \
    #  --slave /usr/bin/$slave $slave /usr/bin/$slave-4.8
}

update_with_slave gcc g++
update_with_slave x86_64-linux-gnu-gcc x86_64-linux-gnu-g++
update gcc-ar
update gcc-nm
update gcc-ranlib
update gcov
update x86_64-linux-gnu-gcc-nm
update x86_64-linux-gnu-gcc-ranlib
update x86_64-linux-gnu-gcc-ar
update x86_64-linux-gnu-gcov
