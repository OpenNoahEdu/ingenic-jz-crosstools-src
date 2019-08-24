#!/bin/sh
#
# Copyright (C) 2008, Ingenic Semiconductor Corp.
#
# This script will compile following packages:
#
#   binutils-2.17, gcc-4.1.2, glibc-2.6.1
#

# Change ${INSTALL_PATH} to yours
INSTALL_PATH=/opt/mipseltools-gcc412-glibc261

# Build and sources paths
BUILD_PATH=`pwd`
SOURCES_PATH=`pwd`

BINUTILS_SOURCES_PATH=${SOURCES_PATH}/binutils
GCC_SOURCES_PATH=${SOURCES_PATH}/gcc
GLIBC_SOURCES_PATH=${SOURCES_PATH}/glibc
KERNEL_HEADERS_PATH=${SOURCES_PATH}/linux-kernel-headers

# Packages name and version
BINUTILS_VER=binutils-2.17
GCC_VER=gcc-4.1.2
GLIBC_VER=glibc-2.6.1
GLIBC_PORTS_VER=glibc-ports-2.6.1

unset CFLAGS
unset CXXFLAGS

export PATH=${INSTALL_PATH}/bin:$PATH

echo "--------------------------------------"
echo "@@ Building binutils ..."
echo "--------------------------------------"

# prepare binutils source
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

echo "----------------------------------"
echo "@@ Building glibc ..."
echo "----------------------------------"

echo "@@ Extracting linux kernel headers ..."
cd ${BUILD_PATH}
tar xjf ${KERNEL_HEADERS_PATH}/linux-headers-2.6.24.3.tar.bz2

LINUX_KERNEL_HEADERS=${BUILD_PATH}/linux-headers-2.6.24.3

# prepare glibc source
cd ${BUILD_PATH}
rm -rf ${GLIBC_VER} glibc-build

tar jxf ${GLIBC_SOURCES_PATH}/${GLIBC_VER}.tar.bz2
cd ${GLIBC_VER}
tar jxf ${GLIBC_SOURCES_PATH}/${GLIBC_PORTS_VER}.tar.bz2
mv ${GLIBC_PORTS_VER} ports
# apply patches
patch -Np1 -i ${GLIBC_SOURCES_PATH}/glibc-2.6.1-cross_hacks-1.patch
patch -Np1 -i ${GLIBC_SOURCES_PATH}/glibc-2.6.1-libgcc_eh-1.patch
patch -Np1 -i ${GLIBC_SOURCES_PATH}/glibc-2.6.1-localedef_segfault-1.patch
patch -Np1 -i ${GLIBC_SOURCES_PATH}/glibc-2.6.1-mawk_fix-1.patch

# configure and build glibc
cd ${BUILD_PATH}
mkdir -v glibc-build
cd glibc-build

echo "libc_cv_forced_unwind=yes" > config.cache
echo "libc_cv_c_cleanup=yes" >> config.cache
echo "libc_cv_mips_tls=yes" >> config.cache

echo '4282c4282
<     3.79* | 3.[89]*)
---
>     3.79* | 3.[89]* | 4.*)' | patch ../${GLIBC_VER}/configure

BUILD_CC="gcc" CC="mipsel-linux-gcc" \
    AR="mipsel-linux-ar" RANLIB="mipsel-linux-ranlib" \
    ../${GLIBC_VER}/configure --prefix=/usr \
    --libexecdir=/usr/lib/glibc --host=mipsel-linux --build=i686-pc-linux-gnu \
    --disable-profile --enable-add-ons --with-tls --enable-kernel=2.6.0 \
    --with-__thread --with-binutils=${INSTALL_PATH}/bin \
    --with-headers=${LINUX_KERNEL_HEADERS} --cache-file=config.cache

make CFLAGS="-O2"

# install glibc
export GLIBC_INSTALL=${BUILD_PATH}/glibc-inst

cd $BUILD_PATH
rm -rf glibc-inst
mkdir -v glibc-inst
cd glibc-build

make install_root=${GLIBC_INSTALL} install

cd ${GLIBC_INSTALL}; tar zcf ${BUILD_PATH}/glibc-build/glibc-lib.tgz lib
cd ${INSTALL_PATH}; tar zxf ${BUILD_PATH}/glibc-build/glibc-lib.tgz
cd ${GLIBC_INSTALL}/usr; tar cfz ${BUILD_PATH}/glibc-build/glibc-usr.tgz .
cd ${INSTALL_PATH}/mipsel-linux; tar xzf ${BUILD_PATH}/glibc-build/glibc-usr.tgz; tar xfz ${BUILD_PATH}/glibc-build/glibc-lib.tgz

# copy inotify.h
cp ${BUILD_PATH}/${GLIBC_VER}/sysdeps/unix/sysv/linux/inotify.h ${INSTALL_PATH}/mipsel-linux/include/sys/

# install linux kernel headers
cp -afr ${LINUX_KERNEL_HEADERS}/* ${INSTALL_PATH}/mipsel-linux/include

# fixed libc.so and libpthread.so
sed -i -e 's/\/usr\/lib\///g' ${INSTALL_PATH}/mipsel-linux/lib/libpthread.so
sed -i -e 's/\/usr\/lib\///g' ${INSTALL_PATH}/mipsel-linux/lib/libc.so

sed -i -e 's/\/lib\///g' ${INSTALL_PATH}/mipsel-linux/lib/libpthread.so
sed -i -e 's/\/lib\///g' ${INSTALL_PATH}/mipsel-linux/lib/libc.so

# install localedata
cd ${BUILD_PATH}/glibc-build
cp -v ${GLIBC_SOURCES_PATH}/${GLIBC_VER}-localedata-Makefile ${BUILD_PATH}/${GLIBC_VER}/localedata/Makefile
cp -v ${GLIBC_SOURCES_PATH}/${GLIBC_VER}-localedata-SUPPORTED ${BUILD_PATH}/${GLIBC_VER}/localedata/SUPPORTED
make localedata/install-locales install_root=${INSTALL_PATH}

echo "----------------------------------"
echo "@@ Building final gcc ..."
echo "----------------------------------"

# prepare gcc source
cd $BUILD_PATH
rm -rf ${GCC_VER} gcc-build

tar jxf ${GCC_SOURCES_PATH}/${GCC_VER}.tar.bz2
cd ${BUILD_PATH}/${GCC_VER}/libiberty
cat strsignal.c | sed -e 's/#ifndef HAVE_PSIGNAL/#if 0/g' >junk.c
cp -f strsignal.c strsignal.c.fixed; mv -f junk.c strsignal.c

# apply patches
cd ${BUILD_PATH}/${GCC_VER}
patch -p0 < ${GCC_SOURCES_PATH}/gcc-4.1_bug27067.patch

# configure and build gcc
cd ${BUILD_PATH}
mkdir -v gcc-build
cd gcc-build

export CC="gcc"

../${GCC_VER}/configure --target=mipsel-linux \
      --host=i686-pc-linux-gnu --prefix=${INSTALL_PATH} \
      --disable-multilib --enable-shared --enable-languages=c,c++ \
      --enable-long-long --with-headers=${INSTALL_PATH}/mipsel-linux/include

make CFLAGS="-O2"

# install gcc
make install

# remove sys-include
rm -rf ${INSTALL_PATH}/mipsel-linux/sys-include

cd $BUILD_PATH

# fix symlink
echo "Fix symlink ..."

cd ${INSTALL_PATH}/mipsel-linux/lib

rm libanl.so
ln -s libanl.so.1 libanl.so

rm libBrokenLocale.so
ln -s libBrokenLocale.so.1 libBrokenLocale.so

rm libcrypt.so
ln -s libcrypt.so.1 libcrypt.so

rm libdl.so
ln -s libdl.so.2 libdl.so

rm libm.so
ln -s libm.so.6 libm.so

rm libnsl.so
ln -s libnsl.so.1 libnsl.so

rm libnss_compat.so
ln -s libnss_compat.so.2 libnss_compat.so

rm libnss_dns.so
ln -s libnss_dns.so.2 libnss_dns.so

rm libnss_files.so
ln -s libnss_files.so.2 libnss_files.so

rm libnss_hesiod.so
ln -s libnss_hesiod.so.2 libnss_hesiod.so

rm libnss_nisplus.so
ln -s libnss_nisplus.so.2 libnss_nisplus.so

rm libnss_nis.so
ln -s libnss_nis.so.2 libnss_nis.so

rm libresolv.so
ln -s libresolv.so.2 libresolv.so

rm librt.so
ln -s librt.so.1 librt.so

rm libthread_db.so
ln -s libthread_db.so.1 libthread_db.so

rm libutil.so
ln -s libutil.so.1 libutil.so

# install mxu_as and jz_mxu.h
cp -v ${SOURCES_PATH}/misc/mxu_as ${INSTALL_PATH}/bin
chmod +x ${INSTALL_PATH}/bin/mxu_as
cp -v ${SOURCES_PATH}/misc/jz_mxu.h ${INSTALL_PATH}/mipsel-linux/include

echo "----------------------------------------------------"
echo "@@ Building binutils/gcc/glibc done @@"
echo "----------------------------------------------------"
