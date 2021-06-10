# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


transform_to_source_path()
{
	local source_folder_path="$1"
	local relative_path_under_mount_to_synchronize="$2"
	
	if $configured_use_rsync; then
		local suffix='/'
	else
		local suffix=''
	fi
	
	printf '%s%s' "$source_folder_path"/"$relative_path_under_mount_to_synchronize" "$suffix"
}

remote_path_only()
{
	local our_mount_name="$1"
	
	# eg 'Users/raph' (for /Users/raph) or '' (for /)
	local relative_path_under_mount_to_synchronize="$2"
	
	# eg 'full' or 'current', etc
	local backup_variant="$3"
	
	# eg '' or "$time_machine_snapshot_date" or "$previous_full_back_up_time_machine_snapshot_date"/"$differential_backup_time_machine_snapshot_date"
	local backup_specific="$4"

	# NOTE: It could be argued that "$configured_machine_name" is sensitive information.
	# For example, a listing of "$configured_machine_name" would allow a hacker to enumerate the machines in the network.
	local path_prefix="$backup_variant"/"$configured_machine_name"/"$our_mount_name"
	local path_suffix="$relative_path_under_mount_to_synchronize"
	local partial_remote_path
	if [ -n "$backup_specific" ]; then
		partial_remote_path="$path_prefix"/"$path_suffix"/"$backup_specific"
	else
		partial_remote_path="$path_prefix"/"$path_suffix"
	fi
	
	local full_remote_path
	if [ -n "$configured_remote_path_prefix" ]; then
		full_remote_path="$configured_remote_path_prefix"/"$partial_remote_path"
	else
		full_remote_path="$partial_remote_path"
	fi
	
	printf '%s' "$full_remote_path"
}

remote_path()
{
	local alias_remote_name="$1"
	
	local our_mount_name="$2"
	
	# eg 'Users/raph' (for /Users/raph) or '' (for /)
	local relative_path_under_mount_to_synchronize="$3"
	
	# eg 'full' or 'replaced/current'
	local backup_variant="$4"
	
	# eg '' or "$time_machine_snapshot_date" or "$previous_full_back_up_time_machine_snapshot_date"/"$differential_backup_time_machine_snapshot_date"
	local backup_specific="$5"
	
	local full_remote_path="$(remote_path_only "$our_mount_name" "$relative_path_under_mount_to_synchronize" "$backup_variant" "$backup_specific")"
	
	if $configured_use_rsync; then
		printf '%s/' "$full_remote_path"
	else
		rclone_create_encrypted_remote "$alias_remote_name" "$full_remote_path"
		printf ''
	fi
}

prefix_remote_path()
{
	local full_remote_path="$1"
	printf '%s' "${configured_remote}${configured_remote_suffix}${full_remote_path}"
}

set_our_mount_name_configuration_path()
{
	local our_mount_name="$1"
	
	our_mount_name_configuration_path="$configuration_folder_path"/"$our_mount_name"
}

_rclone_or_rsync_synchronize()
{
	local our_mount_name="$1"
	local relative_path_under_mount_to_synchronize="$2"
	shift 2
	
	local our_mount_name_configuration_path
	set_our_mount_name_configuration_path "$our_mount_name"
	
	local filter_file_parent_folder_path="$our_mount_name_configuration_path"/"$relative_path_under_mount_to_synchronize"
	
	if $configured_use_rsync; then
		local rsync_filter_file_path="$filter_file_parent_folder_path"/filter.rsync
		file_is_usable "$rsync_filter_file_path"
		if $is_usable; then
			set -- --filter="merge,e ${rsync_filter_file_path}" "$@"
		else
			# Equivalent to -F -F.
			set -- --filter='dir-merge /.rsync-filter' --filter='exclude .rsync-filter' "$@"
		fi
		
		#  ?--acls --xattrs --fake-super are not supported by OS X?
		_rsync_command --archive --hard-links --sparse --one-file-system "$@"
		
	else
		
		local rclone_filter_file_path="$filter_file_parent_folder_path"/filter.rclone
		file_is_usable "$rclone_filter_file_path"
		if $is_usable; then
			set -- "$@" --filter-from "$rclone_filter_file_path"
		fi
		
		rclone_sync "$@"
	fi
}

# This does a full copy.
rclone_or_rsync_full_back_up()
{
	local our_mount_name="$1"
	local source_folder_path="$2"
	local relative_path_under_mount_to_synchronize="$3"
	
	rclone_refresh_temporary_configuration_file
	
	local source_folder_path="$(transform_to_source_path "$source_folder_path" "$relative_path_under_mount_to_synchronize")"

	local remote_full_folder_path="$(remote_path full "$our_mount_name" "$relative_path_under_mount_to_synchronize" full "$time_machine_snapshot_date")"
	
	if $configured_use_rsync; then
		set -- "$source_folder_path" "$remote":"$remote_full_folder_path"
	else
		set -- "$source_folder_path" full:"$remote_full_folder_path"
	fi
	
	_rclone_or_rsync_synchronize "$our_mount_name" "$relative_path_under_mount_to_synchronize" "$@"
}

# In this design, the archive folder with the most recent date is the date of the current back up.
# For example:-
#
# current/
# archive/2020-01-04-101520/
# archive/2020-02-17-003040/
#
# In this example, the current/ folder represents a backup of as of 2020-02-17-003040; 2020-02-17-003040/ contains only the files that changed between 2020-01-04-101520 and 2020-02-17-003040.
#
# There is the possibility that a back up is occurring at the point of inspection, and that neither current/ nor 2020-02-17-003040/ are stable.
#
# This design allows for the deletion (rotation) of older back ups once an older copy of a file is considered stale.
rclone_or_rsync_replaced_back_up()
{
	local our_mount_name="$1"
	local source_folder_path="$2"
	local relative_path_under_mount_to_synchronize="$3"

	rclone_refresh_temporary_configuration_file
	
	local source_folder_path="$(transform_to_source_path "$source_folder_path" "$relative_path_under_mount_to_synchronize")"
	
	local remote_current_folder_path="$(remote_path current "$our_mount_name" "$relative_path_under_mount_to_synchronize" current '')"
	
	local remote_archive_folder_path="$(remote_path archive "$our_mount_name" "$relative_path_under_mount_to_synchronize" archive "$time_machine_snapshot_date")"
	
	if $configured_use_rsync; then
		local is_absolute
		is_absolute_path "$remote_current_folder_path"
		if $is_absolute; then
			remote_archive_folder_path="$(make_path_relative_to "$remote_archive_folder_path" "$remote_current_folder_path")"
		fi
		set -- --backup --backup-dir "$remote_archive_folder_path" "$source_folder_path" "$remote":"$remote_current_folder_path"
	else
		set -- --backup-dir archive:"$remote_archive_folder_path" "$source_folder_path" current:"$remote_current_folder_path"
	fi
	_rclone_or_rsync_synchronize "$our_mount_name" "$relative_path_under_mount_to_synchronize" "$@"
}

rclone_or_rsync_full_then_copy_dest_or_link_dest_or_differential_or_first_incremental_backup()
{
	local our_mount_name="$1"
	local source_folder_path="$2"
	local backup_kind="$3"
	local relative_path_under_mount_to_synchronize="$4"

	rclone_refresh_temporary_configuration_file
	
	local remote_folder_path="$(remote_path_only "$our_mount_name" "$relative_path_under_mount_to_synchronize" full '')"
	
	local most_recent
	rclone_most_recent_folder "$(prefix_remote_path "$remote_folder_path")"
	local previous_full_back_up_time_machine_snapshot_date="$most_recent"
	
	if [ -z "$previous_full_back_up_time_machine_snapshot_date" ]; then
		rclone_or_rsync_full_back_up "$our_mount_name" "$source_folder_path" "$relative_path_under_mount_to_synchronize"
		return 0
	fi
	
	case "$backup_kind" in
		
		copy_dest)
			_rclone_or_rsync_full_copy_dest_or_link_dest_backup "$our_mount_name" "$source_folder_path" "$relative_path_under_mount_to_synchronize" "$previous_full_back_up_time_machine_snapshot_date" 'copy'
		;;
		
		link_dest)
			_rclone_or_rsync_full_copy_dest_or_link_dest_backup "$our_mount_name" "$source_folder_path" "$relative_path_under_mount_to_synchronize" "$previous_full_back_up_time_machine_snapshot_date" 'link'
		;;
		
		differential)
			_rclone_or_rsync_differential_or_first_incremental_backup "$our_mount_name" "$source_folder_path" "$relative_path_under_mount_to_synchronize" "$previous_full_back_up_time_machine_snapshot_date" differential
		;;
		
		incremental)
			_rclone_or_rsync_differential_or_first_incremental_backup "$our_mount_name" "$source_folder_path" "$relative_path_under_mount_to_synchronize" "$previous_full_back_up_time_machine_snapshot_date" incremental
		;;
		
	esac
}

# A full backup needs to have been done using 'rclone_or_rsync_full_back_up' first.
# Produces results identical to a full backup, but uses server side copy or hard links to optimize transfer.
#
# This scheme needs to know the time_machine_snapshot_date of the previous full backup.
_rclone_or_rsync_full_copy_dest_or_link_dest_backup()
{
	local our_mount_name="$1"
	local source_folder_path="$2"
	local relative_path_under_mount_to_synchronize="$3"
	local previous_full_back_up_time_machine_snapshot_date="$4"
	local copy_or_link="$5"

	rclone_refresh_temporary_configuration_file
	
	local source_folder_path="$(transform_to_source_path "$source_folder_path" "$relative_path_under_mount_to_synchronize")"
	
	local remote_this_full_folder_path="$(remote_path full "$our_mount_name" "$relative_path_under_mount_to_synchronize" full "$time_machine_snapshot_date")"
	local remote_previous_full_folder_path="$(remote_path previous "$our_mount_name" "$relative_path_under_mount_to_synchronize" full "$previous_full_back_up_time_machine_snapshot_date")"
	
	if $configured_use_rsync; then
		local is_absolute
		is_absolute_path "$remote_this_full_folder_path"
		if $is_absolute; then
			remote_previous_full_folder_path="$(make_path_relative_to "$remote_previous_full_folder_path" "$remote_this_full_folder_path")"
		fi
		set -- --"$copy_or_link"-dest "$remote_previous_full_folder_path" "$source_folder_path" "$remote":"$remote_this_full_folder_path"
	else
		set -- --copy-dest previous:"$remote_previous_full_folder_path" "$source_folder_path" full:"$remote_this_full_folder_path"
	fi
	_rclone_or_rsync_synchronize "$our_mount_name" "$relative_path_under_mount_to_synchronize" "$@"
}

_rclone_or_rsync_differential_or_first_incremental_backup()
{
	local our_mount_name="$1"
	local source_folder_path="$2"
	local relative_path_under_mount_to_synchronize="$3"
	local previous_full_back_up_time_machine_snapshot_date="$4"
	local differential_or_incremental="$5"

	rclone_refresh_temporary_configuration_file
	
	local source_folder_path="$(transform_to_source_path "$source_folder_path" "$relative_path_under_mount_to_synchronize")"

	local remote_this_differential_or_first_incremental_folder_path="$(remote_path current "$our_mount_name" "$relative_path_under_mount_to_synchronize" "$differential_or_incremental" "$previous_full_back_up_time_machine_snapshot_date"/"$time_machine_snapshot_date")"
	local remote_previous_full_folder_path="$(remote_path previous "$our_mount_name" "$relative_path_under_mount_to_synchronize" full "$previous_full_back_up_time_machine_snapshot_date")"
	
	if $configured_use_rsync; then
		local is_absolute
		is_absolute_path "$remote_this_differential_or_first_incremental_folder_path"
		if $is_absolute; then
			remote_previous_full_folder_path="$(make_path_relative_to "$remote_previous_full_folder_path" "$remote_this_differential_or_first_incremental_folder_path")"
		fi
		set -- --compare-dest "$remote_previous_full_folder_path" "$source_folder_path" "$remote":"$remote_this_differential_or_first_incremental_folder_path"
	else
		set -- --compare-dest previous:"$remote_previous_full_folder_path" "$source_folder_path" current:"$remote_this_differential_or_first_incremental_folder_path"
	fi
	_rclone_or_rsync_synchronize "$our_mount_name" "$relative_path_under_mount_to_synchronize" "$@"
}

# A full backup needs to have been done using 'rclone_or_rsync_full_back_up' first and then a first incremental (actually a differential) backup using 'rclone_or_rsync_first_incremental_backup'.
# Each incremental backup contains differences from the last incremental back up.
#
# This scheme needs to know the time_machine_snapshot_date of the previous full backup and the first incremental backup.
#
# This is a complex scenario.
_rclone_or_rsync_subsequent_incremental_backup()
{
	local our_mount_name="$1"
	local source_folder_path="$2"
	local relative_path_under_mount_to_synchronize="$3"
	local previous_full_back_up_time_machine_snapshot_date="$4"
	local previous_incremental_backup_after_first_full_back_up_time_machine_snapshot_date="$5"
	
	local source_folder_path="$(transform_to_source_path "$source_folder_path" "$relative_path_under_mount_to_synchronize")"

	local remote_current_incremental_folder_path="$(remote_path currentincremental "$our_mount_name" "$relative_path_under_mount_to_synchronize" "$previous_full_back_up_time_machine_snapshot_date"/"$time_machine_snapshot_date")"

	local remote_previous_full_folder_path="$(remote_path previousfull "$our_mount_name" "$relative_path_under_mount_to_synchronize" full "$previous_full_back_up_time_machine_snapshot_date")"
	
	local remote_previous_incremental_folder_path="$(remote_path previousincremental "$our_mount_name" "$relative_path_under_mount_to_synchronize" "$previous_full_back_up_time_machine_snapshot_date"/"$previous_incremental_backup_after_first_full_back_up_time_machine_snapshot_date")"
	
	if $configured_use_rsync; then
		local is_absolute
		is_absolute_path "$remote_current_incremental_folder_path"
		if $is_absolute; then
			remote_previous_full_folder_path="$(make_path_relative_to "$remote_previous_full_folder_path" "$remote_current_incremental_folder_path")"
			remote_previous_incremental_folder_path="$(make_path_relative_to "$remote_previous_incremental_folder_path" "$remote_current_incremental_folder_path")"
		fi
		set -- --compare-dest "$remote_previous_full_folder_path" --compare-dest "$remote_previous_incremental_folder_path" "$source_folder_path" "$remote":"$remote_current_incremental_folder_path"
	else
		set -- --compare-dest previousfull:"$remote_previous_full_folder_path",previousincremental:"$remote_previous_incremental_folder_path" "$source_folder_path" full:"$remote_current_incremental_folder_path"
	fi
	_rclone_or_rsync_synchronize "$our_mount_name" "$relative_path_under_mount_to_synchronize" "$@"
}
