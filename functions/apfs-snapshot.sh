# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


depends mkdir mount_apfs
mount_apfs_snapshot()
{
	local snapshot_name="$1"
	local mounted_root_directory_of_the_base_volume_containing_the_snapshot="$2"
	local mount_point_folder_path="$3"
	
	mkdir -m 0700 -p "$mount_point_folder_path"
	
	# Passing `rdonly` suppresses a noisy message from mount_apfs about mounting implicitly read only.
	mount_apfs -o nodev,noexec,nosuid,rdonly,nobrowse -s "$snapshot_name" "$mounted_root_directory_of_the_base_volume_containing_the_snapshot" "$mount_point_folder_path"
}

depends diskutil
unmount_apfs_snapshot_forcibly()
{
	local mount_point_folder_path="$1"
	
	diskutil quiet unmount force "$mount_point_folder_path"
}

_diskutil_apfs()
{
	diskutil APFS "$@"
}

depends diskutil
_list_all_apfs_snapshot_details()
{
	_diskutil_apfs listSnapshots "$@"
}

# Returns details as a tree to standard out.
# 
# Example:-
# 
# Snapshots for disk1s1 (2 found)
# |
# +-- Name: com.apple.TimeMachine.2021-06-03-085732
# |   XID:  5353929
# |   NOTE: This snapshot sets the minimal allowed size of APFS Container disk1
# |
# +-- Name: com.apple.TimeMachine.2021-06-03-090320
#     XID:  5353966
list_all_apfs_snapshot_details()
{
	local volumeDevice="$1"
	
	_list_all_apfs_snapshot_details "$volumeDevice"
}

# Returns details as a XML property list (plist) to standard out.
#
# Example:-
# 
# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
# <plist version="1.0">
# <dict>
# 	<key>Snapshots</key>
# 	<array>
# 		<dict>
# 			<key>LimitingContainerShrink</key>
# 			<true/>
# 			<key>SnapshotName</key>
# 			<string>com.apple.TimeMachine.2021-06-03-085732</string>
# 			<key>SnapshotXID</key>
# 			<integer>5353929</integer>
# 		</dict>
# 		<dict>
# 			<key>LimitingContainerShrink</key>
# 			<false/>
# 			<key>SnapshotName</key>
# 			<string>com.apple.TimeMachine.2021-06-03-090320</string>
# 			<key>SnapshotXID</key>
# 			<integer>5353966</integer>
# 		</dict>
# 	</array>
# </dict>
# </plist>
list_all_apfs_snapshot_details_as_plist()
{
	local volumeDevice="$1"
	
	_list_all_apfs_snapshot_details -plist "$volumeDevice"
}

# Lists snapshot names in an unsorted newline-delimited list to standard out.
#
# Example:-
# 
# com.bombich.ccc.safetynet.10197797-6B68-477B-A8E9-0C413527368C.2018-11-08-190623
# com.apple.TimeMachine.2021-06-03-085732
# com.apple.TimeMachine.2021-06-03-090320
#
# If mount_point is not a disk returns an error message and exit code 22.
depends tmutil
list_all_apfs_snapshot_names_unsorted()
{
	local volumeDevice="$1"
	
	tmutil listlocalsnapshots "$volumeDevice"
}

depends diskutil
_remove_apfs_snapshot()
{
	local volumeDevice="$1"
	
	_diskutil_apfs deleteSnapshot "$volumeDevice" "$@"
}

remove_apfs_snapshot_by_snapshot_xid()
{
	local snapshot_xid="$1"
	
	_remove_apfs_snapshot -xid "$snapshot_xid"
}

remove_apfs_snapshot_by_snapshot_name()
{
	local snapshot_name="$1"
	
	_remove_apfs_snapshot -name "$snapshot_name"
}

# This can be very slow, but is a great way to recover space, particularly if other programs have made snapshots.
depends tmutil
remove_all_apfs_snapshots()
{
	local volumeDevice="$1"
	
	local urgency=4
	
	# NOTE: The number of nines matters.
	tmutil thinlocalsnapshots "$volumeDevice" 999999999999999 $urgency 1>/dev/null
}
