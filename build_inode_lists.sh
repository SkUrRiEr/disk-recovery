#!/bin/bash

usage () {
	echo $1
	echo
	echo $0 "<image> [<start>] <end>"
	echo
	cat <<EOF
Builds lists of recoverable inodes from any disk or disk image SleuthKit can
read.

image - path to a raw disk image, or a block device
start - number of the first inode to try to read. 0 if not specified.
end   - number of the last inode to try to read

The inodes returned will include directories and other filesystem metadata so
you should specify <end> to be at least 20% above the number of files you
expect to be in the filesystem. Ideally ils would complain that the number is
not a valid inode as it's too high.

This produces a number of files that match "inodes_*.list" in the corrent
directory. These files are the direct output of ils and the variable part of
the filename is the starting inode number. Any existing files matching that
pattern may be overwritten by this tool.

This script will attempt to recover _every_ inode in the range specified.

It will do this by running ils with the full range spcified, then if the last
inode found isn't the end value, trying again starting at the inode after it.

If ils fails wihout finding any inodes, it continues at the inode after the
current starting one.

<end> must be larger than the number of inodes on the filesystem to get full
coverage. This means that eventually ils will return a list of inodes between
some starting value and the last inode on the device. If you are reading from
a damaged physical disk, rather than an image file, this will appear as a
"successful" run of ils without errors. After this, ils will complain about
invalid inodes.

It's expected that running this against a real disk with bad sectors in the
MFT / inode data will produce many errors from ils. These are handled by the
script.

THIS HAS ALMOST NO ERROR HANDLING AND MAY BLINDLY OVERWRITE EXISTING FILES.

READING FROM DISKS WITH DATA LOSS DUE TO BAD SPOTS MAY CAUSE FURTHER DAMAGE.

IT IS STRONGLY RECOMMENDED THAT YOU RUN THIS WITH DISK IMAGES.
EOF

	exit 1;
}

if ! [ -e "$1" ]; then
	usage "First parameter must be a disk image or block device";
fi

if [ $# -lt 2 ]; then
	usage "You must specify an end value"
elif [ $# -eq 2 ]; then
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
