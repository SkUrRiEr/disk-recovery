#!/bin/bash

# $1 == device
# $2 == inode start
# $3 == inode max

if [ $# -eq 2 ]; then
	START=0
	END=$2
else
	START=$2
	END=$3
fi

i=$START

while [ $i -lt $END ]; do
	echo "Searching for inodes between" $i "and" $END "..."

	FILENAME=inodes_$i.list

	ils -f ntfs -i raw $1 -e $i-$END > $FILENAME

	inode=$(tail -n 1 $FILENAME | sed 's/|.*//')

	case $inode in
		""|class|ils|st_ino)
			echo "No inodes found starting at" $i;
			
			rm $FILENAME

			i=$((i + 1))
			;;
		*)
			echo "Found a set of inodes between" $i and $inode inclusive;

			i=$((inode + 1))
			;;
	esac
done

# Combine inodes_*.list files
