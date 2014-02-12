#!/bin/bash

SNAPDIRS="/sc/FileSRV/Snapshot"
LOGFILE=/var/log/lvm-sutostartsnap.log
CURDATA=`date +%Y-%m-%d`			# Current data
LVDEV="/dev/documents"

echo -e >> $LOGFILE

if ! lvscan | grep Snapshot > /dev/null
then
	echo $CURDATA"-"`date +%T`" - SUCCESS - Not found snapshots" >> $LOGFILE
	exit 0
fi

lvscan | grep Snapshot | {
	while read SNAPS
	do
		if [ -z "$SNAPS" ]
		then
			echo $CURDATA"-"`date +%T`" - SUCCESS - Not found snapshots" >> $LOGFILE
			break
		fi

		# Get dev name
		SNAPS=$(echo $SNAPS | awk -F "'" '{print $2}')

		for i in Users Users-All
		do
			if echo $SNAPS | grep "-"$i$ > /dev/null
			then
				# Get date from snapshot name
				SNAPDT=$(echo $SNAPS | awk -F $LVDEV"/" '{printf $2}' | awk -F "-" '{printf $1"-"$2"-"$3}')

				if mount -l | grep $SNAPDIRS/$i/$SNAPDT > /dev/null
				then
					echo $CURDATA"-"`date +%T`" - SUCCESS - snapshot "$SNAPDIRS"/"$i"/"$SNAPDT" already mounted" >> $LOGFILE
					break
				fi

				if [ ! -d $SNAPDIRS/$i/$SNAPDT ]
				then
					if mkdir -p $SNAPDIRS/$i/$SNAPDT
					then
						echo $CURDATA"-"`date +%T`" - SUCCESS - Directory for snapshot "$SNAPDIRS"/"$i"/"$SNAPDT" created" >> $LOGFILE
					else
						echo $CURDATA"-"`date +%T`" - FAILED - Directory for snapshot "$SNAPDIRS"/"$i"/"$SNAPDT" not created" >> $LOGFILE
						exit 1
					fi
				fi
	
				if mount -o ro $SNAPS $SNAPDIRS/$i/$SNAPDT
				then
					echo $CURDATA"-"`date +%T`" - SUCCESS - Snapshot "$SNAPS" mounted to "$SNAPDIRS"/"$i"/"$SNAPDT >> $LOGFILE
				else
					echo $CURDATA"-"`date +%T`" - FAILED - Snapshot "$SNAPS" not mounted to "$SNAPDIRS"/"$i"/"$SNAPDT >> $LOGFILE
					exit 1
				fi
			fi
		done
	done
}

