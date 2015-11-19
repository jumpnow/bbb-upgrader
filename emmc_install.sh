#!/bin/bash

SUPPORT_SCRIPTS="emmc_mk5parts.sh emmc_copy_boot.sh emmc_copy_rootfs.sh"

if [ "x${1}" = "x" ]; then
	IMAGE=console
else
	IMAGE=${1}
fi

if [ "x${2}" = "x" ]; then
	HOSTNAME=beaglebone
else
	HOSTNAME=${2}
fi

for file in $SUPPORT_SCRIPTS; do
	if [ ! -f ./$file ]; then
		echo "Support script not found: $file"
		exit 1
	fi
done

./emmc_mk5parts.sh

if [ $? -ne 0 ]; then
	echo "Script failed: emmc_mk5parts.sh"
	exit 1
fi

./emmc_copy_boot.sh

if [ $? -ne 0 ]; then
	echo "Script failed: emmc_copy_boot.sh"
	exit 1
fi

./emmc_copy_rootfs.sh ${IMAGE} ${HOSTNAME}

if [ $? -ne 0 ]; then
	echo "Script failed: emmc_copy_rootfs.sh ${IMAGE} ${HOSTNAME}"
	exit 1
fi

echo "Success!"
echo "Power off, remove SD card and power up" 

