# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


_rsync_command()
{
	local rsync_environment_file_path="$configuration_folder_path"/rclone.environment.sh
	
	local rsync_path="$(command -v rsync)"
	run_in_new_environment rsync "$rsync_path" -v --rsh "$tools_folder_path"/rsync-ssh-wrapper --checksum-seed="$(secure_signed_32_bit_random_number)" "$@"
}

depends tr wc
make_path_relative_to()
{
	local path="$1"
	local relative_to="$2"
	
	local number_of_slashes="$(printf "$relative_to" | tr '/'$'\n' $'\n''/' | wc -l | tr -d ' ')"
	local number_of_double_dots=$((number_of_slashes + 1))
	
	local result="$path"
	while [ $number_of_double_dots -ne 0 ]
	do
		result=../"$result"
		
		number_of_double_dots=$((number_of_double_dots - 1))
	done
	
	printf '%s' "$result"
}