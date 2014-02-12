#!/bin/bash


######################## VERIABLE BLOCK #####################################

LOGFILE=/var/log/lvm-snapshot.log	# Log file
VGPATH=/dev/documents			# Path to Volume Group
CURDATA=`date +%Y-%m-%d`		# Current data
SNAPDIR="/sc/FileSRV/Snapshot"		# Directory with snapshots
SNAPROTATE="5"				# Rotate snapshot if greater then N
SNAPSIZE="1000M"			# Size of Snapshot (M G default M)

function varinit {
	SNAPROTATE="5"			# Rotate snapshot if greater then N
}


############################# FUNCTIONS BLOCK ############################

echo -e >> $LOGFILE

function createsnap {
	i=$1

	if [ "$2" != "forcecreate" ]
	then
		if [ -b $VGPATH/$CURDATA-$i ]
		then
			echo $CURDATA"-"`date +%T`" - FAILED - Logical Volume Snapshot "$CURDATA-$i" already exist" >> $LOGFILE
			return 0
		fi
	else
		echo $CURDATA"-"`date +%T`" - SUCCESS - Start creating snapshot in FORCE mode, "$CURDATA" will be replaced for "$i  >> $LOGFILE
	fi

	if lvcreate -s -n $CURDATA-$i -L $SNAPSIZE $VGPATH/$i
	then
		echo $CURDATA"-"`date +%T`" - SUCCESS - Logical Volume Snapshot "$CURDATA-$i" created with size: "$SNAPSIZE >> $LOGFILE
	else
		echo $CURDATA"-"`date +%T`" - FAILED - Logical Volume Snapshot "$CURDATA-$i" not created" >> $LOGFILE
		return 1
	fi

	if mkdir -p $SNAPDIR/$i/$CURDATA
	then
		echo $CURDATA"-"`date +%T`" - SUCCESS - Directory for snapshot "$SNAPDIR/$i/$CURDATA" created" >> $LOGFILE
	else
		echo $CURDATA"-"`date +%T`" - FAILED - Directory for snapshot "$SNAPDIR/$i/$CURDATA" not created" >> $LOGFILE
		return 1
	fi

	if mount -o ro $VGPATH/$CURDATA-$i $SNAPDIR/$i/$CURDATA
	then
		echo $CURDATA"-"`date +%T`" - SUCCESS - Mounted snapshot "$VGPATH/$CURDATA-$i" to "$SNAPDIR/$i/$CURDATA >> $LOGFILE
	else
		echo $CURDATA"-"`date +%T`" - FAILED - Not mounted snapshot "$VGPATH/$CURDATA-$i" to "$SNAPDIR/$i/$CURDATA >> $LOGFILE
		return 1
	fi

	return 0
}

function rotatesnaptask {
	i=$1

	FROTATE="disable"
	
	if [ "$2" == "forcerotate" ]
	then
		echo $CURDATA"-"`date +%T`" - SUCCESS - Force rotating for "$i >> $LOGFILE
		FROTATE="enable"
	fi

	echo $CURDATA"-"`date +%T`" - SUCCESS - Checking snapshot rotating for "$i >> $LOGFILE
	cd $SNAPDIR/$i

	SNAPCOUNT=$(ls | wc -l)
	SNAPROTATEFORCE=""

	if [ "$FROTATE" == "enable" ]
	then
		SNAPCOUNT="1"
		SNAPROTATEFORCE=$SNAPROTATE
		SNAPROTATE="1"
	fi

	if [ $SNAPROTATE -gt $SNAPCOUNT ]
	then
		echo $CURDATA"-"`date +%T`" - SUCCESS - for "$i" found "$SNAPCOUNT" snapshots, threshold is "$SNAPROTATE", rotate disabled" >> $LOGFILE
		return 1
	fi

	if [ "$FROTATE" == "enable" ]
	then
		NUMROTATE="1"
		echo $CURDATA"-"`date +%T`" - SUCCESS - for "$i" found "$NUMROTATE" snapshots for rotate" >> $LOGFILE
		NUMROTATE=$SNAPROTATEFORCE
	else
		NUMROTATE=$(($SNAPCOUNT - $SNAPROTATE))
		echo $CURDATA"-"`date +%T`" - SUCCESS - for "$i" found "$NUMROTATE" snapshots for rotate" >> $LOGFILE
	fi

	ls | {
		while read OLDSNAP
		do
			if [ $NUMROTATE == 0 ]
			then
				continue
			else
				NUMROTATE=$((NUMROTATE - 1))
			fi

			if [ -z $OLDSNAP ]
			then
				echo $CURDATA"-"`date +%T`" - FAILED - Zero lenght name" >> $LOGFILE
				continue
			fi

			if ! echo $OLDSNAP | grep -E "????-??-??"
			then
				echo $CURDATA"-"`date +%T`" - FAILED - snapshot name: "$OLDSNAP" not vailedated, and not rotated" >> $LOGFILE
				continue
			fi

			if [ "$FROTATE" == "enable" ]
			then
				if [ $OLDSNAP == $CURDATA ]
				then
					echo $CURDATA"-"`date +%T`" - SUCCESS - snapshot name: "$OLDSNAP" matched with "$CURDATA", rotate it force" >> $LOGFILE
				else
					echo $CURDATA"-"`date +%T`" - FAILED - snapshot name: "$OLDSNAP" not match with "$CURDATA", skip rotate" >> $LOGFILE
					continue
				fi
			fi

			if [ -d $OLDSNAP ]
			then
				if [ -b $VGPATH/$OLDSNAP-$i ]
				then
					# Rotate OLD Snapshot
					echo $CURDATA"-"`date +%T`" - SUCCESS - Starting snapshot rotating: "$VGPATH"/"$OLDSNAP-$i" because snapshot older than "$SNAPROTATE" days"  >> $LOGFILE

					if umount $SNAPDIR/$i/$OLDSNAP
					then
						echo $CURDATA"-"`date +%T`" - SUCCESS - Umounted "$SNAPDIR/$i/$OLDSNAP >> $LOGFILE
					else
						echo $CURDATA"-"`date +%T`" - FAILED - Not umounted "$SNAPDIR/$i/$OLDSNAP >> $LOGFILE
						continue
					fi
					
					if lvremove -f $VGPATH/$OLDSNAP-$i
					then
						echo $CURDATA"-"`date +%T`" - SUCCESS - Logical Volume Snapshot Removed $VGPATH/"$OLDSNAP-$i >> $LOGFILE
					else
						echo $CURDATA"-"`date +%T`" - FAILED - Logical Volume Snapshot not Removed $VGPATH/"$OLDSNAP-$i >> $LOGFILE
						continue
					fi

					if rm -rf ./$OLDSNAP
					then
						echo $CURDATA"-"`date +%T`" - SUCCESS - Deleted directory "`pwd`/$OLDSNAP >> $LOGFILE

					else
						echo $CURDATA"-"`date +%T`" - FAILED - not deleted directory "`pwd`/$OLDSNAP >> $LOGFILE
						continue
					fi
				else
					echo $CURDATA"-"`date +%T`" - FAILED - Logical Volume Snapshot not found $VGPATH/"$OLDSNAP-$i >> $LOGFILE
				fi
			else
				echo $CURDATA"-"`date +%T`" - FAILED - not found direcory "`pwd`/$OLDSNAP >> $LOGFILE
			fi
		done
	}
	echo $CURDATA"-"`date +%T`" - SUCCESS - Complited snapshot rotating for "$i >> $LOGFILE

	return 0
}


################## RUN BLOCK #######################

varinit

if [ ! -z "$1" ] && [ "$1" != "replace" ]
then
	echo ""
	echo "Invalid invocation argument: $1"
	echo "Valid arguments:"
	echo "1) replace - Force recreate current snapshot"
	echo ""

	exit 1
fi

if [ "$1" == "replace" ]
then
	rotatesnaptask Users forcerotate
	varinit
	createsnap Users forcecreate
	varinit

	rotatesnaptask Users-All forcerotate
	varinit
	createsnap Users-All forcecreate
	varinit
else
	createsnap Users
	rotatesnaptask Users

	createsnap Users-All
	rotatesnaptask Users-All
fi


