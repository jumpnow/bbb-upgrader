#!/bin/bash
#
# Script to install a system onto the BBB eMMC.
# This script handles the root fs partition.
#
# It should be invoked as:
#
#  ./emmc_copy_rootfs.sh <image> [<hostname>]
#
# where <image> is something like qt5 or console.
#
# Assumes the following files are available in the local directory:
#
#  1) ${IMAGE}-image-beaglebone.tar.xz where ${IMAGE} is the 1st arg to this script
#

MACHINE=beaglebone
SRCDIR=.

if [ "x${1}" = "x" ]; then
	echo -e "\nUsage: ${0} <image> [<hostname>]\n"
	exit 1 
fi

if [ ! -d /media ]; then
	echo "Mount point /media does not exist"
	exit 1
fi

IMAGE=${1}

echo "IMAGE: ${IMAGE}"

if [ "x${2}" = "x" ]; then
        TARGET_HOSTNAME=$MACHINE
else
        TARGET_HOSTNAME=${2}
fi

echo -e "HOSTNAME: $TARGET_HOSTNAME\n"


if [ ! -f "${SRCDIR}/${IMAGE}-image-${MACHINE}.tar.xz" ]; then
        echo "File not found: ${SRCDIR}/${IMAGE}-image-${MACHINE}.tar.xz"
        exit 1
fi

DEV=/dev/mmcblk1p2

if [ ! -b $DEV ]; then
	echo "Block device $DEV does not exist"
	exit 1
fi

echo "Formatting $DEV as ext4"
mkfs.ext4 -q -L ROOT $DEV

echo "Mounting $DEV"
mount $DEV /media

echo "Extracting ${IMAGE}-image-${MACHINE}.tar.xz to /media"
tar -C /media -xJf ${SRCDIR}/${IMAGE}-image-${MACHINE}.tar.xz

echo "Writing hostname to /etc/hostname"
echo ${TARGET_HOSTNAME} > /media/etc/hostname        

if [ -f ${SRCDIR}/interfaces ]; then
	echo "Writing interfaces to /media/etc/network/"
	cp ${SRCDIR}/interfaces /media/etc/network/interfaces
fi

if [ -f ${SRCDIR}/wpa_supplicant.conf ]; then
	echo "Writing wpa_supplicant.conf to /media/etc/"
	cp ${SRCDIR}/wpa_supplicant.conf /media/etc/wpa_supplicant.conf
fi

echo "Unmounting $DEV"
umount $DEV

echo "Done"

