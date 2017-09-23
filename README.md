# disk-recovery

Horrifically simple NTFS disk recovery using SleuthKit

## MASSIVE WARNING

***DO NOT USE THIS IF YOU ARE IN ANY WAY UNSURE OF WHAT YOU'RE DOING.***

***THIS HAS ALMOST NO ERROR HANDLING AND MAY BLINDLY OVERWRITE EXISTING FILES.***

***READING FROM DISKS WITH DATA LOSS DUE TO BAD SPOTS MAY CAUSE FURTHER DAMAGE.***

***IT IS STRONGLY RECOMMENDED THAT YOU RUN THIS WITH DISK IMAGES, NOT DIRECTLY OFF A DAMAGED DISK.***

***THESE SCRIPTS CAN BE USED IN WAYS WHICH ARE HORRIFICALLY UNSAFE FOR PERFORMING REAL DISK RECOVERY.***

***YOU ARE ON YOUR OWN, THIS SHOULD ONLY BE USED AS A LAST RESORT WHEN ALL OTHER DISK RECOVERY OPTIONS HAVE FAILED.***

## Assumptions

1. You know what you're doing.
2. You are recovering from a "raw" image of the disk, i.e. a byte-for-byte copy made using `ddrescue` or equivalent. <sup>1</sup>
3. You have sufficient storage to store all the data returned, which may be significantly more than you expect
4. You are prepared to not recover everything.
5. You are running the recovery scripts on a Linux machine.

(<sup>1</sup>) Yes, you can recover directly from failed but readable disks, however this is ***NOT RECOMMENDED***. See above.

## Prerequisites

 - SleuthKit commandline tools from http://www.sleuthkit.org/sleuthkit
 - Pipe Viewer ("pv") from http://www.ivarch.com/programs/pv.shtml
 - `iconv` which should be installed by default.

Both of these should be packaged for your Linux distribution.

These scripts probably work on BSDs and MacOS X, however this has never been attempted.

Windows, including it's embedded Linux environment, is not supported and is unlikely to work.

## Usage

1. Copy the bad disk
2. Build a list of inodes
3. Recover data from those inodes

### Copying bad disks

There are a number of tools to do this including but not limited to `ddrescue`.

It's left to the reader to determine the best way to do this for their particular situation.

### Building a list of inodes

As I understand it, for the purposes of this discussion, and as a lie you can understand, NTFS's Master File Table is something in between a list of addresses of inods and a binary tree.

This means that for a disk with damage to the MFT or inodes themselves it's possible that you can recover non-contiguous ranges of inodes.

Therefore the `build_inode_list.sh` script takes a range (or 0 to a maximum) of inodes to try to get data for, then produces files containing contiguous sets of inode data.

#### Commandline Options

`build_inode_list.sh <disk_image> [<start>] <end>`

 - `<disk_image>` a disk image.
 - `<start>` an optional starting inode
 - `<end>` the highest inode to try to recover

If `<start>` is omitted, `0` is used instead.

`<end>` should be at least 20% higher than the number of files you expect to recover as inodes include system data structures and directories.

#### Mechanism

This script starts at the "start" inode and asks `ils` to produce a listing of all inodes between the current start inode and the end inode.

The listing returned is briefly checked and if empty discarded.

Otherwise we retrieve the highest inode number in the listing returned and continue searching from the inode after it.

Errors from `ils` are expected as the data in the disk image is likely to be incomplete or if you're running this on an actual disk, unfetchable.

#### Results

This will produce a number of files named `inodes_*.list` in the current directory and will blindly overwrite any it finds.

The variable part of the filename is the start inode `ils` was given for the run that produced the file.

These files are otherwise unmodified and unadorned `ils` output files with headers.

***NOTE:*** This will blindly overwrite any files matching `inodes_*.list`

At the moment, it's left as an exercise to the reader to produce a list of unrecoverable inodes and attempt recovery from them.

As I understand it, if `ils` cannot get data on an inode, it's unrecoverable using SleuthKit.

It is possible (and desirable) that your `<end>` value is greater than the number of inodes on the disk. So if a run finished without error, then `ils` has determined that it's reached the end of the MFT, therefore you've found the "last" inode. The script does not recognise this situation and will blindly continue searching which causes `ils` to complain about non-existent inodes.

### Recovering Data

The recovery script is designed to be "re-entrant" in that it discards any incomplete files and skips files which already exist.

So it is recommended that you make a copy of an existing backup (assuming you have one) then recover into that directory. This will speed up the process as files which exist in the backup will not be copied.

If recovering from an actual disk, it is possible that subsequent runs will recover files which were previously unrecoverable.

***Note:*** The algorithm to choose whether to copy a file or not only checks the existence of the file in question, it does not check any other attributes of the file or it's contents. If you know of any files which have been changed since your last backup, you should discard them from the directory you are recovering to.

#### Commandline Options

`recover_data.sh <disk_image> <ils_file> [<ils_file> ...]`

- `<disk_image>` a disk image.
- `<ils_file>` a file containing output from `ils`.

You can specify multiple files on the commandline and all will be recovered from. A typical commandline would look like `recover_data.sh ../disk.img ../inodes/inodes_*.list`

#### Mechanism

This script reads each inode in the file, skipping any which are any of:

- not allocated
- empty

Then uses `ffind` to find their filename and if it does not exist, uses `icat` to dump the file data. (`pv` is used to display a nice progress bar)

As the inodes found are likely to include directories as well as files, these are also dumped *as files*. If it is then discovered that the directory is actually a file, it will have the extension `.dirdata` added to it's name.

***Note:*** The directory renaming code will blindly overwrite files with the `.dirdata` extension, however they should be very rare. It also has issues with directories in deep directory structures appearing in the "wrong" order, which shouldn't happen in practice.

***Note:*** Filenames are transliterated into ASCII, so international characters may be lost. This step should not be necessary, however it has not been removed as it's harmless in my testing.

#### Results

This will recover all complete files it can from the inode lists passed into their original directories, creating as much of the file and directory structure as possible.

NTFS filesytems have a lot of metadata in invisible-but-named files (With names starting with `$`) which are also recovered, even though it's probably useless.

Permissions, ownership, ACLs and dates are not preserved as this was unncessary for my purposes - it should be relatively easy to add code to the script to recover parts of that data.

Any incomplete files are stored in a file called `failed.log` in the current directory. This file is only appended to. The `ils` output for incomplete files and files where `ffind` cannot recover a name is saved into `failed.inodes` which is, again, only appended to.

It should be possible to try again by running the script with `failed.inodes`, however this is likely to only be useful when recovering from actual disks as it's possible that the hard disk amy have recovered those sectors by the time you try again. Obviously this isn't recommeded.

It's up to the user to find and delete any unwanted files this script creates.

## Next Steps

If these scripts cannot recover your data, it's likely that it is *not* recoverable by means available in the home.

Firstly you should attempt to find out which files or directories you are missing, either through examining backups or through the use of `ntfsls` from NTFS-v3. This can be used to guide your recovery attempts so you focus on the _important_ parts of your data rather than the stuff you don't mind losing.

Options I'm aware of:

- There are a few proprietary / commercial software packages which claim to be able to recover data from NTFS filesystems. You might get better results with them.
- Commercial services might be able to attempt recovery procedures which are impractical in the home - however these will be extremely expensive.
- There are tools which are able to recover specific types of files (usually photos) by scanning the disk. If there are files *of those types* who's inode data has been destroed, these tools might be able to recover them - however it is up to you to figure out what their filenames were.

There are always more options for recovery, however you will need to determine when to abandon recovery attempts.
