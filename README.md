## bbb-upgrader

Some scripts to support upgrading BeagleBone Black systems.

Additional documentation can be found [here][upgrading-bbb-systems].

I'm only testing with Yocto built BBB systems

* that are not using an initrd
* that have a 4GB eMMC (Rev. C boards)

The interesting scripts are 

* emmc\_uEnv.txt
* bbb\_upgrade.sh
* manage\_boot\_flag\_partition.sh

Because the eMMC is not accessible externally, the remaining scripts are here to support the initial system install to an SD card and then the initial eMMC install from the booted SD card system.

### Quickstart

Just kidding...

You have to build some binaries for the BBB with Yocto first.

The files you need are

* MLO-beaglebone
* u-boot-beaglebone.img
* \<some-image-name\>-image-beaglebone.tar.xz

If you already have them, then you are ready to get started.

If not, there are some instructions [here][building-bbb-systems].

The scripts can handle the binaries in the same location where they are run or you can export an environment variable called `OETMP` that points to your bitbake `TMPDIR`.

The files will be searched for under

    ${OETMP}/deploy/images/beaglebone/

That assumes you haven't changed the bitbake `DEPLOY_DIR`. If you have, then figure out yourself how to specify `OETMP` or just modify the copy_ scripts. They are not difficult.
	
You will also need the name of the *dtb* you want the kernel to use. 

The normal procedure is to include it in your kernel recipe so that the Yocto kernel scripts will have built and installed in onto the *rootfs* for you.

Update the **fdtfile** variable in `uEnv.txt` and `emmc_uEnv.txt` with the *dtb* you want to use instead of the default `bbb-nohdmi.dtb` that I use for testing.

#### SD card install

Assuming your SD card shows up at `/dev/sdb` run the following

    sudo ./mk2parts sdb
    ./copy_boot.sh sdb
    ./copy_rootfs.sh sdb <some-image-name>	
    ./copy_emmc_install.sh sdb <some-image-name> [<hostname>]
	

Put the card in the BBB and boot the system holding down S2.

### eMMC install
	
From a shell session on the BBB that is now running off the SD card

    root@beaglebone:~# cd emmc
    root@beaglebone:~/emmc# ./emmc_install.sh <some-image-name> [<hostname>]	
	
When that completes, remove the SD card and boot the eMMC system.

### Looking at the new system

The system is now ready for the `bbb_upgrade.sh` script.

The `eMMC` was partitioned as follows by the `emmc_mk5parts.sh` script run by the `emmc_install.sh` script

    Device         Boot   Start     End Sectors  Size Id Type
    /dev/mmcblk0p1 *        128  131199  131072   64M  c W95 FAT32 (LBA)
    /dev/mmcblk0p2       133120 2230271 2097152    1G 83 Linux
    /dev/mmcblk0p3      2230272 4327423 2097152    1G 83 Linux
    /dev/mmcblk0p4      4327424 7667711 3340288  1.6G  5 Extended
    /dev/mmcblk0p5      4329472 4460543  131072   64M  c W95 FAT32 (LBA)
    /dev/mmcblk0p6      4462592 7667711 3205120  1.5G 83 Linux

The current root partition is `/dev/mmcblk0p2`.

The `bbb_upgrade.sh` script alternately uses `/dev/mmcblk0p2` and `/dev/mmcblk0p3` as the new *rootfs* partition when it performs an upgrade. 

It chooses the new *rootfs* partition based on whichever partition is not the current *rootfs*.

The `/dev/mmcblk0p5` partition is used by the `uEnv.txt` u-boot script to read and write some flag files to determine which partition to load as the *rootfs*. 

The `manage_boot_flag_partition.sh` is a Linux script that also manages flag files on this partition.

This is the script that confirms that the new partition actually worked.

If this script isn't run the first time after booting a new *rootfs* following an upgrade, the system will revert back to the old *rootfs* on the next boot.

The `manage_boot_flag_partition.sh` script can be run anytime and I would normally add it to the systems as an init script. If there is nothing to do, the `manage_boot_flag_partition.sh` script won't do anything.

The `bbb_upgrade.sh` is responsible for formatting `/dev/mmcblk0p5` and populating the initial flag files.

### Running an Upgrade

A locaton is needed for the new image tarball, so make use of `/dev/mmcblk0p6`

    mkfs.ext4 -q -L DATA /dev/mmcblk0p6
	mkdir /data
	echo "/dev/mmcblk0p6 /data auto defaults 0 0" > /etc/fstab
	mount /dev/mmcblk0p6
	
Copy the tarball image and the `bbb_upgrade.sh` and `manage_boot_flag_partition.sh` script to the new /data directory on the BBB.

For example

    scp console-image-beaglebone.tar.xz bbb_upgrade.sh manage_boot_flag_partition.sh root@<bbb-ip>:/data

Then on the BBB run `bbb_upgrade.sh` like this

    root@bbb:~# cd /data
    root@bbb:/data# ./bbb_upgrade.sh console-image-beaglebone.tar.xz
    Checking for an eMMC : OK
    Checking that there is no SD card : OK
    Finding the current root partition : /dev/mmcblk0p2
    The new root will be : /dev/mmcblk0p3
    Checking the new root partition size : OK
    Checking for a /dev/mmcblk0p5 partition : OK
    Checking the /dev/mmcblk0p5 flag partition size : OK
    Check that /dev/mmcblk0p5 is not in use : OK
    Checking for a /dev/mmcblk0p6 partition : OK
    Checking that /mnt is not in use : OK
    Formatting partition /dev/mmcblk0p3 as ext4 : OK
    Mounting /dev/mmcblk0p3 on /mnt : OK
    Extracting new root filesystem console-image-beaglebone.tar.xz to /mnt : OK
    Copying config files from current system : OK
    Unmounting /dev/mmcblk0p3 : OK
    Formatting the flag partition /dev/mmcblk0p5 :
    mkfs.fat 3.0.28 (2015-05-16)
    OK
    Mounting the flag partition /dev/mmcblk0p5 on /mnt : OK
    Creating file '/mnt/three' : OK
    Unmounting /dev/mmcblk0p5 from /mnt : OK

    A new system was installed onto : /dev/mmcblk0p3

    Reboot to use the new system.
    root@bbb:/data#

After rebooting note the new rootfs

    root@bbb:~# cat /proc/cmdline
    console=ttyO0,115200n8 consoleblank=0 root=/dev/mmcblk0p3 ro rootfstype=ext4 rootwait

	root@bbb:~# mount | grep mmcblk0
    /dev/mmcblk0p3 on / type ext4 (rw,relatime,data=ordered)
    /dev/mmcblk0p6 on /data type ext4 (rw,relatime,data=ordered)


Make sure to run `manage_boot_flag_partition.sh` or the next reboot will revert back to `/dev/mmcblk0p2`.

The upgrade script copied over the old `/etc/fstab` and a `/data` mount point for `/dev/mmcblk0p6` so

    root@bbb:~# cd /data
    root@bbb:/data# ./manage_boot_flag_partition.sh

    Checking for an eMMC : OK
    Checking that there is no SD card : OK
    Finding the current root partition : /dev/mmcblk0p3
    Checking there is a /dev/mmcblk0p5 partition : OK
    Checking that /dev/mmcblk0p5 is not in use : OK
    Checking that /mnt is not in use : OK
    Mounting /dev/mmcblk0p5 on /mnt : OK
    Updating flag files on /dev/mmcblk0p5 : OK
    Unmounting /dev/mmcblk0p5 : OK
    root@bbb:/data#

### Summary

There is plenty of script cleanup and simplification to be done.

But the basic framework is in place and working.


[upgrading-bbb-systems]: http://www.jumpnowtek.com/beaglebone/Upgrade-strategy-for-BBB.html
[building-bbb-systems]: http://www.jumpnowtek.com/beaglebone/BeagleBone-Systems-with-Yocto.html
