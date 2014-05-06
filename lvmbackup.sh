#!/bin/bash

# Version 1.0.0
# Use:  thisscript.sh /original /backup /snap /increment targetname
# for example:
# /sc/sh_cmd/lvmbackup.sh /sc/FileSRV/Users /sc/FileSRV/BackUp/Users \
#	/sc/FileSRV/BackUp/Snapshot/Users /sc/FileSRV/BackUp/Incremental-Users Users


TARGETDIR=$1						# Directory with original files
BACKUPDIR=$2						# Directory with copy original files
SNAPDIR=$3						# Directory with snapshot from orig. files
INCDIR=$4						# Directory with incremental modified files
LVMTARGETNAME=$5					# Target name
LVMPREFIX=documents					# LVM name volume group
LVMDEV=/dev/"$LVMPREFIX"/"$LVMTARGETNAME"		# LVM devmapper path
SNAPNAME="$LVMTARGETNAME""-SNAP"			# Snapshot name
LVMSNAPDEV=/dev/"$LVMPREFIX"/"$SNAPNAME"		# LVM snapshot devmapper path
LVMSNAPSZ=1G						# Size of snapshot
LOGFILE=/var/log/lvmbackup.log				# Log file
CURDATA=`date +%Y-%m-%d`				# Current date


# Usage: logwrite <message text> <status 1/0>
logwrite() {
	MSGTXT="$1"
	STATUSLOG="$2"

	if [ "$STATUSLOG" == "0" ]
	then
		STATUSLOG="SUCCESS"
	else
		STATUSLOG="FAILED "
	fi

	echo $CURDATA"-"`date +%T`" - "$STATUSLOG" - "$MSGTXT"" >> $LOGFILE
}

# Usage: endprocess <exit status 1/0>
endprocess() {
	echo "" >> $LOGFILE

	if [ "$1" == "failed" ]
	then
		exit 1
	else
		exit 0
	fi
}

# Usage: checkpath <Mount dir /mnt/lvm> <Device /dev/dev1>
checkpath() {
	DIR=$1		# Check by mounted dir (indirect)
	DEV=$2		# Check by device (direct)
	DEVNBDIR=""	# Devname by Dir

	if /sbin/mount | grep -m 1 "$DIR"
	then
		DEVNBDIR="$(/sbin/mount | grep -m 1 "$DIR" | awk '{print $1}')"
		logwrite "Device name for mounted dir "$DIR" is: "$DEVNBDIR"" 0

		# Determine link by dir mount
		if CURRENTLINK="$(ls -la "$DEVNBDIR" | rev | awk '{print $1}' | rev)"
		then
			logwrite "Link for device "$DEVNBDIR" is: "$CURRENTLINK"" 0
		else
			logwrite "Link for device "$DEVNBDIR" is not determined" 1
			return 1
		fi
	else
		logwrite "Device name for mounted dir "$DIR" is not determined" 1
		return 1
	fi

	if [ -b "$DEV" ]
	then
		logwrite "Device "$DEV" exist" 0

		# Determine link by dev directly
		if COMPARELINK="$(ls -la "$DEV" | rev | awk '{print $1}' | rev)"
		then
			logwrite "Link for device "$DEV" is "$COMPARELINK"" 0
		else
			logwrite "Link for device "$DEV" is not determined" 1
			return 1
		fi
	else
		logwrite "Device "$DEV" is not exist" 1
		return 1
	fi

	if [ "$CURRENTLINK" == "$COMPARELINK" ]
	then
		logwrite "For devices "$DEVNBDIR" and "$DEV" link is: "$CURRENTLINK"" 0
	else
		logwrite "For devices "$DEVNBDIR" and "$DEV" link is not identical" 1
		return 1
	fi
}

removesnapshot() {
	if [ "$1" == "normalumount" ]
	then
		UMSTAT="normalumount"
	else
		UMSTAT="umount"
	fi

	if mount -l | grep "$SNAPDIR"
	then
		logwrite "Directory for snapshot "$SNAPDIR" mounted" 0
	else
		logwrite "Directory for snapshot "$SNAPDIR" not mounted" 1
		return 1
	fi
	if checkpath "$SNAPDIR" "$LVMSNAPDEV"
	then
		logwrite "Checked ("$SNAPDIR") ("$LVMSNAPDEV") " 0
	else
		logwrite "Check failed ("$SNAPDIR") ("$LVMSNAPDEV")" 1
		return 1
	fi

	if [ "$UMSTAT" != "normalumount" ]
	then
		logwrite "LVM snapshot "$LVMSNAPDEV" already mounted to "$SNAPDIR"" 1
	fi

	if /sbin/umount "$LVMSNAPDEV" > /dev/null 2>&1
	then
		logwrite "LVM snapshot "$LVMSNAPDEV" unmounted from "$SNAPDIR"" 0
	else
		logwrite "LVM snapshot "$LVMSNAPDEV" not unmounted from "$SNAPDIR"" 1
		return 1
	fi

	if [ -b "$LVMSNAPDEV" ]
	then
		if [ "$UMSTAT" != "normalumount" ]
		then
			logwrite "LVM Snapshot exist: "$LVMSNAPDEV"" 1
		fi
	
		if /sbin/lvremove -f "$LVMSNAPDEV" > /dev/null 2>&1
		then
			logwrite "LVM Snapshot "$LVMSNAPDEV" removed" 0
		else
			logwrite "LVM Snapshot "$LVMSNAPDEV" not removed" 1
			return 1
		fi
	fi
}

echo $CURDATA"-"`date +%T`" - SUCCESS - LVM BackUp session started for "$LVMTARGETNAME"" >> $LOGFILE

if [ -d "$TARGETDIR" ]
then
	logwrite "Directory with LVM partition "$TARGETDIR" found" 0
else
	logwrite "Directory with LVM partition "$TARGETDIR" not found" 1
	endprocess failed
fi

if [ -b "$LVMDEV" ]
then
	logwrite "LVM Device "$LVMDEV" found" 0
else
	logwrite "LVM Device "$LVMDEV" not found" 1
	endprocess failed
fi

if checkpath "$TARGETDIR" "$LVMDEV"
then
	logwrite "LVM Device "$LVMDEV" mounted to "$TARGETDIR"" 0
else
	logwrite "LVM Device "$LVMDEV" not mounted to "$TARGETDIR"" 1
	endprocess failed
fi

if removesnapshot
then
	logwrite "Snapshot removed" 0
else
	logwrite "Snapshot not removed"
fi

# Create snapshot
if /sbin/lvcreate -s -n "$SNAPNAME" -L "$LVMSNAPSZ" "$LVMDEV" > /dev/null 2>&1 
then
	logwrite "LVM Snapshot "$LVMSNAPDEV" created" 0
else
	logwrite "LVM Snapshot "$LVMSNAPDEV" not created" 1
	endprocess failed
fi

if mount -o ro "$LVMSNAPDEV"  "$SNAPDIR" > /dev/null 2>&1
then
	logwrite "LVM Snapshot "$LVMSNAPDEV" mounted to "$SNAPDIR"" 0
else
	logwrite "LVM Snapshot "$LVMSNAPDEV" not mounted to "$SNAPDIR"" 1
	endprocess failed
fi

if [ -d "$BACKUPDIR" ]
then
	logwrite "Dir "$BACKUPDIR" for backups exist" 0
else
	logwrite "Dir "$BACKUPDIR" for backups not exist" 1
	endprocess failed
fi

if [ -d "$INCDIR" ]
then
	logwrite "Dir "$INCDIR" for incremental backups exist" 0
else
	logwrite "Dir "$INCDIR" for incremental backups not exist" 1
	endprocess failed
fi

echo $CURDATA"-"`date +%T`" - SUCCESS - Rsync started" >> $LOGFILE

if /usr/bin/rsync -a -q --delete --backup --backup-dir="$INCDIR" --suffix="-"`date +%F--%H-%M-%S` "$SNAPDIR""/" "$BACKUPDIR""/" > /dev/null 2>&1
then
	logwrite "Rsynced SRC: "$SNAPDIR", DST: "$BACKUPDIR", INCRM: "$INCDIR"" 0
else
	logwrite "Rsynced SRC: "$SNAPDIR", DST: "$BACKUPDIR", INCRM: "$INCDIR"" 1
	endprocess failed
fi

removesnapshot normalumount

endprocess

