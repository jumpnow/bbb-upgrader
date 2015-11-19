#!/bin/sh

echo -e -n "\nChecking for an eMMC : "

ls /dev/mmc* | grep -q mmcblk0

if [ $? -eq 1 ]; then
	echo "FAIL"
        echo "There is no /dev/mmcblk0"
        exit 1
fi

echo "OK"

echo -e -n "Checking that there is no SD card : "

ls /dev/mmc* | grep -q mmcblk1

if [ $? -eq 0 ]; then
	echo "FAIL"
        echo "An SD card is present. Not going to continue." 
        exit 1
fi

echo "OK"

echo -e -n "Finding the current root partition : "

cat /proc/cmdline | grep -q mmcblk0p2

if [ $? -eq 0 ]; then
        CURRENT_ROOT=/dev/mmcblk0p2
else
        cat /proc/cmdline | grep -q mmcblk0p3

        if [ $? -eq 0 ]; then
                CURRENT_ROOT=/dev/mmcblk0p3
        else
		echo "FAIL"
                echo "Current root device is not mmcblk0p2 or mmcblk0p3"
                exit 1
        fi
fi

echo "$CURRENT_ROOT"


echo -e -n "Checking there is a /dev/mmcblk0p5 partition : "

fdisk -l /dev/mmcblk0 | grep -q mmcblk0p5

if [ $? -eq 1 ]; then
        echo "FAIL"
        echo "There is no /dev/mmcblk0p5 partition"
        exit 1
fi

echo "OK"

echo -e -n "Checking that /dev/mmcblk0p5 is not in use : "

mount | grep -q mmcblk0p5

if [ $? -eq 0 ]; then
        echo "FAIL"
        echo "/dev/mmcblk0p5 is already mounted"
        exit 1
fi

echo "OK"

echo -e -n "Checking that /mnt is not in use : "

mount | grep -q /mnt

if [ $? -eq 0 ]; then
	echo "FAIL"
	echo "/mnt is in use by another mounted filesystem"
	exit 1
fi

echo "OK"

echo -e -n "Mounting /dev/mmcblk0p5 on /mnt : "

mount -t vfat /dev/mmcblk0p5 /mnt

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Failed to mount /dev/mmcblk0p5 on /mnt as type vfat"
	exit 1
fi

echo "OK"

echo -e -n "Updating flag files on /dev/mmcblk0p5 : "

if [ "$CURRENT_ROOT" = "/dev/mmcblk0p2" ]; then
	if [ ! -e /mnt/two ]; then
		touch /mnt/two
	fi

	if [ ! -e /mnt/two_ok ]; then
		touch /mnt/two_ok
	fi

	rm -rf /mnt/three*
else
	if [ ! -e /mnt/three ]; then
		touch /mnt/three
	fi

	if [ ! -e /mnt/three_ok ]; then
		touch /mnt/three_ok
	fi

	rm -rf /mnt/two*
fi

echo "OK"

echo -e -n "Unmounting /dev/mmcblk0p5 : "

umount /dev/mmcblk0p5

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Failed to unmount /dev/mmcblk0p5"
	exit 1
fi

echo "OK"
