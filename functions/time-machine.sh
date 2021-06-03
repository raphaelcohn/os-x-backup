# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


# Lists time machine snapshots to standard out as their dates, sorted from oldest to newest.
# A time machine date is formatted `YYYY-MM-DD-HHMMSS`.
# Optionally takes a deviceVolume.
#
# If mount_point is not a disk returns an error message and exit code 22.
#
# Example 1 (list_all_time_machine_snapshot_dates_sorted):-
# 
# Snapshot dates for all disks:
# 2021-06-03-085732
# 2021-06-03-090320
#
# Example 2 (list_all_time_machine_snapshot_dates_sorted '/'):-
# 
# Snapshot dates for disk /:
# 2021-06-03-085732
# 2021-06-03-090320
depends tmutil
list_all_time_machine_snapshot_dates_sorted()
{
	if [ $# -gt 0 ]; then
		local deviceVolume="$1"
		tmutil listlocalsnapshotdates "$deviceVolume"
	else
		tmutil listlocalsnapshotdates
	fi
}

time_machine_snapshot_date_to_name()
{
	local time_machine_snapshot_date="$1"
	printf 'com.apple.TimeMachine.%s' "$time_machine_snapshot_date"
}

# This takes one or more APFS snapshots; there is one snapshot for each APFS deviceVolume that Time Machine has been told to backup.
depends tmutil tr awk rm
take_time_machine_snapshot()
{
	local temporary_file="$TMPDIR"/details
	
	# Returns "Created local snapshot with date: 2021-06-03-075957" to standard out.
	tmutil localsnapshot 1>"$temporary_file"
	
	time_machine_snapshot_date="$(tr -d ' ' <"$temporary_file" | awk -F: '{print $2}')"
	rm "$temporary_file"
}

# Does not error if the snapshot does not exist.
depends tmutil
delete_time_machine_snapshot()
{
	local time_machine_snapshot_date="$1"
	tmutil deletelocalsnapshots "$time_machine_snapshot_date" 1>/dev/null
}
