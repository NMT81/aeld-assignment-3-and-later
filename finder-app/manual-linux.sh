#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j $(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    #make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules dtbs
fi

echo "Adding the Image in outdir"
cp -v ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p rootfs && cd rootfs
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log


cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make distclean
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
else
    cd busybox
fi

# TODO: Make and install busybox
    make -j $(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=../rootfs install

echo "Library dependencies"
${CROSS_COMPILE}readelf -a ../rootfs/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ../rootfs/bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
cd "$OUTDIR"
CROSS_ROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
cp -v ${CROSS_ROOT}/lib/ld-linux-aarch64.so.1 rootfs/lib/
cp -v ${CROSS_ROOT}/lib64/libm.so.6 rootfs/lib64/
cp -v ${CROSS_ROOT}/lib64/libresolv.so.2 rootfs/lib64/
cp -v ${CROSS_ROOT}/lib64/libc.so.6 rootfs/lib64/

# TODO: Make device nodes
cd ${OUTDIR}/rootfs
sudo mknod -m 600 dev/console c 5 1
sudo mknod -m 666 dev/null c 1 3

# TODO: Clean and build the writer utility
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}
if [ -e writer ]
then
    cp -v writer ${OUTDIR}/rootfs/home/
fi

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cd ${FINDER_APP_DIR}
if [ -e finder.sh ]; then
    cp -v finder.sh ${OUTDIR}/rootfs/home/
fi
if [ -e finder-test.sh ]; then
    cp -v finder-test.sh ${OUTDIR}/rootfs/home/
fi
if [ -e autorun-qemu.sh ]; then
    cp -v autorun-qemu.sh ${OUTDIR}/rootfs/home/
fi
mkdir -p ${OUTDIR}/rootfs/home/conf
if [ -e ../conf/username.txt ]; then
    cp -v ../conf/username.txt ${OUTDIR}/rootfs/home/conf/
fi
if [ -e ../conf/assignment.txt ]; then
    cp -v ../conf/assignment.txt ${OUTDIR}/rootfs/home/conf/
fi
sed -i 's|../conf/assignment.txt|conf/assignment.txt|' ${OUTDIR}/rootfs/home/finder-test.sh

# TODO: Chown the root directory

# TODO: Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
sudo find . -print0 | sudo cpio --null -H newc -ov --owner root:root | gzip -f > ../initramfs.cpio.gz
