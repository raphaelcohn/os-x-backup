# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


_exit_message()
{
	local code="$1"
	local message="$2"
	printf "%s\n" "$message"
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
	local folder_path="$1"
	if [ ! -e "$folder_path" ]; then
		exists=false
	elif [ ! -f "$folder_path" ]; then
		exists=false
	elif [ ! -r "$folder_path" ]; then
		exists=false
	else
		exists=true
	fi
}

file_is_usable()
{
	local folder_path="$1"
	if [ ! -e "$folder_path" ]; then
		is_usable=false
	elif [ ! -f "$folder_path" ]; then
		is_usable=false
	elif [ ! -r "$folder_path" ]; then
		is_usable=false
	elif [ ! -s "$folder_path" ]; then
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

depends od head tr
insecure_32_bit_random_number()
{
	exit_if_character_device_missing /dev/urandom
	od -vAn -N4 -t u4 </dev/urandom | head -n 1 | tr -d ' '
}

depends mkdir rm
make_temporary_folder()
{
	mkdir -m 0700 -p "$temporary_folder_path"
	
	local random_number="$(insecure_32_bit_random_number)"
	
	export TMPDIR="$temporary_folder_path"/"$random_number"
	mkdir -m 0700 "$TMPDIR" || exit_can_not_create_message "Did someone else create our folder trying to hack us?"
	
	remove_temporary_directory()
	{
		rm -rf "$TMPDIR"
	}
	trap remove_temporary_directory EXIT
}
