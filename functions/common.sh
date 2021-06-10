# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


_exit_message()
{
	local code="$1"
	local message="$2"
	
	if [ -n ${_program_name+set} ]; then
		local program_name="$_program_name"
	else
		local program_name='(unknown)'
	fi
	
	printf "%s:%s\n" "$program_name" "$message"
	exit $code
}

exit_help_message()
{
	_exit_message 0 "$1"
}

_exit_error_message()
{
	local code="$1"
	local message="$2"
	_exit_message $code "$message" 1>&2
}

exit_error_message()
{
	_exit_error_message 1 "$1"
}

# See https://man.openbsd.org/sysexits.3

exit_usage_message()
{
	local EX_USAGE=64
	_exit_error_message $EX_USAGE "$1"
}

exit_configuration_message()
{
	local EX_CONFIG=64
	_exit_error_message $EX_CONFIG "$1"
}

exit_system_file_message()
{
	local EX_OSFILE=71
	_exit_error_message $EX_OSFILE "$1"
}

exit_temporary_fail_message()
{
	local EX_TEMPFAIL=77
	_exit_error_message $EX_TEMPFAIL "$1"
}

exit_can_not_create_message()
{
	local EX_CANTCREAT=73
	_exit_error_message $EX_CANTCREAT "$1"
}

exit_permission_message()
{
	local EX_NOPERM=77
	_exit_error_message $EX_NOPERM "$1"
}

exit_if_folder_missing()
{
	local folder_path="$1"
	if [ ! -e "$folder_path" ]; then
		exit_configuration_message "folder $folder_path does not exist"
	fi
	if [ ! -r "$folder_path" ]; then
		exit_permission_message "folder $folder_path is not readable"
	fi
	if [ ! -d "$folder_path" ]; then
		exit_configuration_message "folder $folder_path is not a folder"
	fi
	if [ ! -x "$folder_path" ]; then
		exit_permission_message "folder $folder_path is not searchable"
	fi
}

exit_if_configuration_file_missing()
{
	local file_path="$1"
	if [ ! -e "$file_path" ]; then
		exit_configuration_message "configuration file $file_path does not exist"
	fi
	if [ ! -r "$file_path" ]; then
		exit_permission_message "configuration file $file_path is not readable"
	fi
	if [ ! -f "$file_path" ]; then
		exit_configuration_message "configuration file $file_path is not a file"
	fi
	if [ ! -s "$file_path" ]; then
		exit_configuration_message "configuration file $file_path is empty"
	fi
}

exit_if_character_device_missing()
{
	local character_device_path="$1"
	if [ ! -e "$character_device_path" ]; then
		exit_system_file_message "Character device $character_device_path does not exist"
	fi
	if [ ! -r "$character_device_path" ]; then
		exit_system_file_message "Character device $character_device_path is not readable"
	fi
	if [ ! -c "$character_device_path" ]; then
		exit_system_file_message "Character device $character_device_path is not a character device"
	fi
}

exit_if_symlink_missing()
{
	local symlink_path="$1"
	if [ ! -L "$symlink_path" ]; then
		exit_system_file_message "Symlink $symlink_path is not a symlink"
	fi
}

folder_is_usable()
{
	local folder_path="$1"
	if [ ! -e "$folder_path" ]; then
		is_usable=false
	elif [ ! -d "$folder_path" ]; then
		is_usable=false
	elif [ ! -r "$folder_path" ]; then
		is_usable=false
	elif [ ! -x "$folder_path" ]; then
		is_usable=false
	else
		is_usable=true
	fi
}

file_exists()
{
	local file_path="$1"
	if [ ! -e "$file_path" ]; then
		exists=false
	elif [ ! -f "$file_path" ]; then
		exists=false
	elif [ ! -r "$file_path" ]; then
		exists=false
	else
		exists=true
	fi
}

file_is_usable()
{
	local file_path="$1"
	if [ ! -e "$file_path" ]; then
		is_usable=false
	elif [ ! -f "$file_path" ]; then
		is_usable=false
	elif [ ! -r "$file_path" ]; then
		is_usable=false
	elif [ ! -s "$file_path" ]; then
		is_usable=false
	else
		is_usable=true
	fi
}

export PATH=/usr/bin:/bin:/usr/sbin:/sbin
depends()
{
	local binary
	for binary in "$@"
	do
		if ! $(command -v "$binary" 1>/dev/null); then
			exit_system_file_message "Binary $binary is not present on the PATH ($PATH)"
		fi
	done
}

_secure_random_number()
{
	local output_type="$1"
	
	exit_if_character_device_missing /dev/urandom
	od -vAn -N4 -t "$output_type" </dev/urandom | head -n 1 | tr -d ' '
}

depends od head tr
secure_unsigned_32_bit_random_number()
{
	_secure_random_number u4
}

depends od head tr
secure_signed_32_bit_random_number()
{
	_secure_random_number d4
}

depends mkdir rm
make_temporary_folder()
{
	mkdir -m 0700 -p "$temporary_folder_path"
	
	local random_number="$(secure_unsigned_32_bit_random_number)"
	
	export TMPDIR="$temporary_folder_path"/"$random_number"
	mkdir -m 0700 "$TMPDIR" || exit_can_not_create_message "Did someone else create our folder trying to hack us?"
	
	remove_temporary_directory()
	{
		rm -rf "$TMPDIR"
	}
	trap remove_temporary_directory EXIT
}


depends mkdir cat sleep rm
singleton_instance_lock()
{
	single_instance_lock_folder_path=''

	local potential_single_instance_lock_folder_path="$temporary_folder_path"/"$_program_name"
	local lock_holder_pid_file_path="$potential_single_instance_lock_folder_path"/lock_holder.pid
	local loop_count=0
	
	local exit_code
	while true
	do
		set +e
			mkdir -m 0700 "$potential_single_instance_lock_folder_path" 1>/dev/null 2>/dev/null
			exit_code=$?
		set -e
		
		if [ $exit_code -eq 0 ]; then
			printf '%s\n' $$ >"$lock_holder_pid_file_path"
			single_instance_lock_folder_path="$potential_single_instance_lock_folder_path"
			break
		fi
		
		local loop_division=$((loop_count % 5))
		if [ $loop_division -eq 0 ]; then
			local lock_holder_pid=''
			set +e
				lock_holder_pid="$(cat "$lock_holder_pid_file_path" 2>/dev/null)"
			set -e
			
			if [ -z "$lock_holder_pid" ]; then
				lock_holder_pid='(unknown)'
			fi
			
			printf '%s:%s\n' "$_program_name" "Still waiting for single instance lock $potential_single_instance_lock_folder_path held by process $lock_holder_pid"
		fi
		loop_count=$((loop_count + 1))
		
		# Non-portable fractional sleep
		set +e
			sleep 0.1 1>/dev/null 2>/dev/null
			exit_code=$?
		set -e
		
		if [ $exit_code -ne 0 ]; then
			sleep 1 1>/dev/null 2>/dev/null
		fi
		
	done
	
	remove_single_instance_lock_folder_path()
	{
		if [ -n "$single_instance_lock_folder_path" ]; then
			rm -rf "$single_instance_lock_folder_path"
			single_instance_lock_folder_path=''
		fi
		
		remove_temporary_directory
	}
	
	trap remove_single_instance_lock_folder_path EXIT
}

set_configuration_folder_path()
{
	if [ -n "${OS_X_CONFIGURATION_FOLDER_PATH+set}" ]; then
		cd "$OS_X_CONFIGURATION_FOLDER_PATH" 1>/dev/null 2>/dev/null
			configuration_folder_path="$(pwd)"
		cd - 1>/dev/null 2>/dev/null
		unset OS_X_CONFIGURATION_FOLDER_PATH
	else
		cd ~ 1>/dev/null 2>/dev/null
			configuration_folder_path="$(pwd)"/.config/os-x-backup
		cd - 1>/dev/null 2>/dev/null
	fi
	exit_if_folder_missing "$configuration_folder_path"
}

run_in_new_environment()
{
	local environment_name="$1"
	shift 1

	local environment_file_path="$configuration_folder_path"/"$environment_name".environment.sh
	
	/usr/bin/env -i "$tools_folder_path"/environment-wrapper "$environment_file_path" "$@"
}

depends head
first_character()
{
	printf '%s' "$1" | head -c 1
}

depends tail
last_character()
{
	printf '%s' "$1" | tail -c 1
}

is_absolute_path()
{
	local path="$1"
	
	if [ "$(first_character "$path")" = '/' ]; then
		is_absolute=true
	else
		is_absolute=false
	fi
}
