#!/bin/sh
#
# Copyright (C) 2008, Ingenic Semiconductor Corp.
#
# This script will compile following packages:
#
#   binutils-2.17, gcc-4.1.2
#

# Change ${INSTALL_PATH} to yours
INSTALL_PATH=~/opt/mipseltools-gcc412

# Build and sources paths
BUILD_PATH=`pwd`/build
SOURCES_PATH=`pwd`

BINUTILS_SOURCES_PATH=${SOURCES_PATH}/binutils
GCC_SOURCES_PATH=${SOURCES_PATH}/gcc
KERNEL_HEADERS_PATH=${SOURCES_PATH}/linux-kernel-headers

# Packages name and version
BINUTILS_VER=binutils-2.17
GCC_VER=gcc-4.1.2

unset CFLAGS
unset CXXFLAGS

export PATH=${INSTALL_PATH}/bin:$PATH

echo "--------------------------------------"
echo "@@ Building binutils ..."
echo "--------------------------------------"

# prepare binutils source
mkdir -p ${BUILD_PATH}
cd ${BUILD_PATH}
rm -rf ${BINUTILS_VER} binutils-build
tar jxf ${BINUTILS_SOURCES_PATH}/${BINUTILS_VER}.tar.bz2

# configure and build binutils
mkdir -v binutils-build
cd binutils-build

../${BINUTILS_VER}/configure --target=mipsel-linux --prefix=${INSTALL_PATH}
make CFLAGS="-O2 -std=gnu89 -w"

# install binutils
make install

echo "----------------------------------"
echo "@@ Building bootstrap gcc ..."
echo "----------------------------------"

# prepare gcc source
cd ${BUILD_PATH}
rm -rf ${GCC_VER} gcc-build

tar jxf ${GCC_SOURCES_PATH}/${GCC_VER}.tar.bz2
cd ${BUILD_PATH}/${GCC_VER}/libiberty
cat strsignal.c | sed -e 's/#ifndef HAVE_PSIGNAL/#if 0/g' >junk.c
cp -f strsignal.c strsignal.c.fixed; mv -f junk.c strsignal.c

# configure and build gcc
cd ${BUILD_PATH}
mkdir -v gcc-build
cd gcc-build

../${GCC_VER}/configure --target=mipsel-linux \
      --host=i686-pc-linux-gnu --prefix=${INSTALL_PATH} \
      --disable-shared --disable-threads --disable-multilib \
      --enable-languages=c

make CFLAGS="-O2 -std=gnu89" all-gcc

# install gcc
make install-gcc

echo "----------------------------------------------------"
echo "@@ Building binutils/gcc done @@"
echo "----------------------------------------------------"

echo "You can run: "
echo "echo 'PATH=\$PATH:$INSTALL_PATH/bin/' >> ~/.zshrc"
