#!/bin/bash

LOGFILE="/var/log/lvm-autostart.log"	# Log file
CURDATA=`date +%Y-%m-%d`		# Current data
LVMFILE="/sc/fileserverlvm.img"		# File with LVM partitions
LOOPDEVS="/dev/loop11"			# Loop device for mount LVM file with LVM partitions
VGNAME=documents			# Name of Volume Group
LVMDIRS="/sc/FileSRV"			# Directory where is resides files on LVM

echo -e >> $LOGFILE

# Check LVM File
if [ -f $LVMFILE ]
then
	echo $CURDATA"-"`date +%T`" - SUCCESS - File "$LVMFILE" found" >> $LOGFILE
else
	echo $CURDATA"-"`date +%T`" - FAILED - File "$LVMFILE" no found" >> $LOGFILE
	exit 1
fi

# Check already used loop device
if losetup -a | grep $LOOPDEVS
then
	echo $CURDATA"-"`date +%T`" - FAILED - Loop device "$LOOPDEVS" already used, not possible for mount" >> $LOGFILE
	exit 1
else
	echo $CURDATA"-"`date +%T`" - SUCCESS - Loop device "$LOOPDEVS" not used and ready to mount" >> $LOGFILE
fi

# Mount LVM file as block device
if losetup $LOOPDEVS $LVMFILE
then
	echo $CURDATA"-"`date +%T`" - SUCCESS - Loop device "$LOOPDEVS" mounted file "$LVMFILE >> $LOGFILE
else
	echo $CURDATA"-"`date +%T`" - FAILED - Loop device "$LOOPDEVS" not mount file "$LVMFILE >> $LOGFILE
	exit 1
fi

# Change status of Volume Group
if vgchange -a y $VGNAME
then
	echo $CURDATA"-"`date +%T`" - SUCCESS - Changed Volume Group "$VGNAME" status to ACTIVE" >> $LOGFILE
else
	echo $CURDATA"-"`date +%T`" - FAILED - Not changed Volume Group "$VGNAME" status to ACTIVE" >> $LOGFILE
fi

# Check block device with Volume Group
for i in "Users" "Users-All"
do
	if [ -b /dev/$VGNAME/$i ]
	then
		echo $CURDATA"-"`date +%T`" - SUCCESS - Block device /dev/"$VGNAME"/"$i" exist" >> $LOGFILE
	else
		echo $CURDATA"-"`date +%T`" - FAILED - Block device /dev/"$VGNAME"/"$i" not exist" >> $LOGFILE
		exit 1
	fi
done

# Check directory for mount
for i in "Users" "Users-All"
do
	if [ -d $LVMDIRS/$i ]
	then
		echo $CURDATA"-"`date +%T`" - SUCCESS - Directory "$LVMDIRS"/"$i" exist" >> $LOGFILE
	else
		echo $CURDATA"-"`date +%T`" - FAILED - Directory "$LVMDIRS"/"$i" not exist" >> $LOGFILE
		exit 1
	fi
done

# Mount Logical Volumes
for i in "Users" "Users-All"
do
	if mount "/dev/"$VGNAME"/"$i $LVMDIRS"/"$i
	then
		echo $CURDATA"-"`date +%T`" - SUCCESS - Mounted /dev/"$VGNAME"/"$i" to "$LVMDIRS"/"$i >> $LOGFILE
	else
		echo $CURDATA"-"`date +%T`" - FAILED - Not mounted /dev/"$VGNAME"/"$i" to "$LVMDIRS"/"$i >> $LOGFILE
		exit 1
	fi
done

