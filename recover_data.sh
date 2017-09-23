#!/bin/bash

usage () {
	echo $1
	echo
	echo $0 "<image> <ils_file> [<ils_file> ...]"
	echo
	cat <<EOF
Recovers files and directories from a disk or disk image SleuthKit can read.

image    - path to a raw disk image, or a block device
ils_file - output from ils - mutiple files can be spcified

This recovers files and directories, i.e. the full file and directory structure
from any fileystem image SleuthKit can read into the current directory.

Files which are not recoverable are output into "failed.log" in the current
directory. Inodes which cannot be copied or lack filenames are saved to
"failed.inodes" in the current directory.

Note that this is hardcoded to expect RAW images. i.e. byte-for-byte disk
images or disks themselves.

If the ils output contains inodes for directories, these will also be recovered
as FILES. If this script encounters a file that the disk's paths indicate is
actually a directory, it'll be renamed to *.dirdata automatically. Note that
this script assumes that in the case of some directory like /a/b/c, inodes will
either appear in the order a, b, c; or c will appear before a.

Special inodes, e.g. NTFS filesystem structures, will also be recovered.

Multiple ils files can be specified and all will be used to recover data.

Filenames are transliterated to ASCII, so international characters may be lost.

This will not overwrite existing files with the same name as potential
recovered files, so it _should_ be safe to run multiple times in an initially
empty directory or in a directory containing files and directories from
previous recovery attempts using other tools.

However other than that, THIS HAS ALMOST NO ERROR HANDLING AND MAY BLINDLY
OVERWRITE EXISTING FILES.

READING FROM DISKS WITH DATA LOSS DUE TO BAD SPOTS MAY CAUSE FURTHER DAMAGE.

IT IS STRONGLY RECOMMENDED THAT YOU RUN THIS WITH DISK IMAGES.
EOF

	exit 1;
}

if ! [ -e "$1" ]; then
	usage "First parameter must be a disk image or block device";
fi

DISK="$1"

while [ $# -gt 2 ]; do
	echo "Recovering inodes listed in $2 ..."

	if ! [ -f "$2" ]; then
		usage "Second parameter must be a file";
	fi

	cat $2 | while IFS="|" read inode alloc uid gid mtime atime ctime crtime mode nlink size; do
		case $inode in
			class|ils|st_ino)
				continue;
				;;
		esac

		if [ $size -eq 0 ]; then
			echo "Skipping inode #" $inode "as it's empty"
			continue;
		fi

		if [ $alloc = "f" ]; then
			echo "Skipping inode #" $inode "as it's not allocated"
			continue;
		fi

		FILENAME="./$(ffind -f ntfs -i raw "$DISK" $inode | iconv -t "ASCII//TRANSLIT" -)"

		if [ "$FILENAME" = "./File name not found for inode" -o "$FILENAME" = "./" ] ; then
			echo "Inode #" $inode "does not have a filename."

			echo $inode"|"$alloc"|"$uid"|"$gid"|"$mtime"|"$atime"|"$ctime"|"$crtime"|"$mode"|"$nlink"|"$size >> failed.inodes

			continue;
		fi

		echo "Inode #" $inode "is at" $FILENAME;

		DIR=$(dirname "$FILENAME")

		if [ -f "$DIR" ]; then
			echo "$DIR is also a directory, fixing."
			mv "$DIR" "$DIR.dirdata"
		fi

		mkdir -p "$DIR"

		if ! [ -e "$FILENAME" ]; then
			(
				icat -f ntfs -h -r -i raw "$DISK" $inode || (
					rm -f "$FILENAME"
					echo "$FILENAME" >> failed.log
					echo $inode"|"$alloc"|"$uid"|"$gid"|"$mtime"|"$atime"|"$ctime"|"$crtime"|"$mode"|"$nlink"|"$size >> failed.inodes
				)
			) | pv -s $size > "$FILENAME"
		fi
	done

	shift 1;
done
