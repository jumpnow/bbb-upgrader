#!/bin/sh

if [ "x${1}" = "x" ]; then
	echo "Usage: ${0} <full-path-to-new-image-file>"
	exit 1
fi

if [ ! -f "${1}" ]; then
	echo "Image file not found: ${1}"
	exit 1
fi

echo -e -n "Checking for an eMMC : "

ls /dev/mmc* | grep -q mmcblk0

if [ $? -eq 1 ]; then
	echo "FAIL"
	echo "No /dev/mmcblk0. Can't handle this."
	exit 1
fi

echo "OK"

echo -e -n "Checking that there is no SD card : "

ls /dev/mmc* | grep -q mmcblk1

if [ $? -eq 0 ]; then
	echo "FAIL"
	echo "An SD card is present. Please remove and try again."
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

if [ "${CURRENT_ROOT}" = "/dev/mmcblk0p2" ]; then
	NEW_ROOT=/dev/mmcblk0p3
else
	NEW_ROOT=/dev/mmcblk0p2
fi

echo "The new root will be : $NEW_ROOT" 


echo -e -n "Checking the new root partition size : "

SECTORS=`fdisk -l /dev/mmcblk0 | grep $NEW_ROOT | awk '{ print $4 }'`

# since it's more work to parse the Size units, use Sectors
# 2097152 sectors * 512 bytes/sector = 1GB
if [ $SECTORS -lt 2000000 ]; then
	echo "FAIL"
	echo "The new root partition [ $NEW_ROOT ] is too small, at least 1GB is required."
	echo ""
	echo "Here is the current partitioning of [ /dev/mmcblk0 ]"
	echo ""
	fdisk -l /dev/mmcblk0 
	exit 1
fi

echo "OK"

echo -e -n "Checking for a /dev/mmcblk0p5 partition : "

fdisk -l /dev/mmcblk0 | grep -q mmcblk0p5

if [ $? -eq 1 ]; then
	echo "FAIL"
	echo "There is no /dev/mmcblk0p5 partition"
	exit 1
fi

echo "OK"

echo -e -n "Checking the /dev/mmcblk0p5 flag partition size : "

SECTORS=`fdisk -l /dev/mmcblk0 | grep mmcblk0p5 | awk '{ print $4 }'`

if [ $SECTORS -ne 131072 ]; then
	echo "FAIL"
	echo "The size of the flag partition /dev/mmcblk0p5 is unexpected."
	echo ""
	echo "Here is the current partitioning of [ /dev/mmcblk0 ]"
	echo ""
	fdisk -l /dev/mmcblk0 
	exit 1
fi

echo "OK"

echo -e -n "Check that /dev/mmcblk0p5 is not in use : "

mount | grep -q mmcblk0p5

if [ $? -eq 0 ]; then
	echo "FAIL"
	echo "/dev/mmcblk0p5 is already mounted"
	exit 1
fi

echo "OK"

echo -e -n "Checking for a /dev/mmcblk0p6 partition : "

fdisk -l /dev/mmcblk0 | grep -q mmcblk0p6

if [ $? -eq 1 ]; then
	echo "FAIL"
	echo "There is no /dev/mmcblk0p6 partition"
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

echo -e -n "Formatting partition $NEW_ROOT as ext4 : "

mkfs.ext4 -q $NEW_ROOT

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Error formatting the new root partition [ $NEW_ROOT ]"
	exit 1
fi

echo "OK"

echo -e -n "Mounting $NEW_ROOT on /mnt : "

mount $NEW_ROOT /mnt

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Error mounting partition $NEW_ROOT"
	exit 1
fi

echo "OK"

echo -e -n "Extracting new root filesystem ${1} to /mnt : "

tar -C /mnt -xJf ${1}

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Error extracting the root filesystem"
	umount $NEW_ROOT
	exit 1
fi

echo "OK"

echo -e -n "Copying config files from current system : "

cp /etc/fstab /mnt/etc/fstab

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Error copying /etc/fstab to new system"
	umount $NEW_ROOT
	exit 1
fi

cp /etc/hostname /mnt/etc/hostname

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Error copying /etc/hostname to new system"
	umount $NEW_ROOT
	exit 1
fi

mkdir /mnt/data

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Error creating /data directory on new system"
	umount $NEW_ROOT
	exit 1
fi 

echo "OK"

echo -e -n "Unmounting $NEW_ROOT : "

umount $NEW_ROOT

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Error unmounting $NEW_ROOT"
	exit 1
fi

echo "OK"

echo "Formatting the flag partition /dev/mmcblk0p5 : "

mkfs.vfat -F 32 /dev/mmcblk0p5 -n FLAG

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Failed formatting /dev/mmcblk0p5 as FAT";
	exit 1
fi

echo "OK"

echo -e -n "Mounting the flag partition /dev/mmcblk0p5 on /mnt : "

mount /dev/mmcblk0p5 /mnt

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Failed to mount /dev/mmcblk0p5";
	exit 1
fi

echo "OK"

if [ "$NEW_ROOT" = "/dev/mmcblk0p2" ]; then
	echo -e -n "Creating file '/mnt/two' : "
	touch /mnt/two
else
	echo -e -n "Creating file '/mnt/three' : "
	touch /mnt/three
fi

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Unable to create flag file";
	umount /dev/mmcblk0p5
	exit 1
fi

echo "OK"

echo -e -n "Unmounting /dev/mmcblk0p5 from /mnt : "

umount /dev/mmcblk0p5

if [ $? -ne 0 ]; then
	echo "FAIL"
	echo "Fail to unmount /dev/mmcblk0p5"
	exit 1
fi

echo "OK"

echo -e "\nA new system was installed onto : $NEW_ROOT"
echo -e "\nReboot to use the new system."
