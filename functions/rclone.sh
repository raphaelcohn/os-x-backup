# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


set_rclone_root_path()
{
	rclone_root_path="$(pwd)"/library/rclone
}

depends readlink
set_rclone_version()
{
	rclone_current_path="$rclone_root_path"/current
	exit_if_symlink_missing "$rclone_current_path"
	
	rclone_version="$(readlink "$rclone_current_path")"
}

depends uname
set_rclone_parent_path()
{
	local uname_operating_system="$(uname -s)"
	local uname_architecture="$(uname -m)"
	
	_put_rclone_on_path_architecture_error()
	{
		local supported_architectures="$1"
		exit_system_file_message "Only the 64-bit architecture${supported_architectures} are supported for rclone on uname -s "$uname_operating_system" uname -m $uname_architecture"
	}
	
	local rclone_operating_system
	case "$uname_operating_system" in
		
		Darwin)
			rclone_operating_system=osx
			
			case "$uname_architecture" in
				
				arm64)
					rclone_architecture=arm64
				;;
				
				x86_64)
					rclone_architecture=amd64
				;;
				
				*)
					_put_rclone_on_path_architecture_error 's arm64 and x86_64'
				;;
				
			esac
		;;
		
		FreeBSD)
			rclone_operating_system=freebsd
			
			case "$uname_architecture" in
				
				amd64)
					rclone_architecture=amd64
				;;
				
				*)
					_put_rclone_on_path_architecture_error 'amd64'
				;;
				
			esac
		;;
		
		Linux)
			rclone_operating_system=linux
			
			case "$uname_architecture" in
				
				aarch64)
					rclone_architecture=arm64
				;;
				
				x86_64)
					rclone_architecture=amd64
				;;
				
				*)
					_put_rclone_on_path_architecture_error 's arm64 and x86_64'
				;;
				
			esac
		;;
		
		NetBSD)
			rclone_operating_system=netbsd
			
			case "$uname_architecture" in
				
				amd64)
					rclone_architecture=amd64
				;;
				
				*)
					_put_rclone_on_path_architecture_error 'amd64'
				;;
				
			esac
		;;
		
		OpenBSD)
			rclone_operating_system=openbsd
			
			case "$uname_architecture" in
				
				amd64)
					rclone_architecture=amd64
				;;
				
				*)
					_put_rclone_on_path_architecture_error 'amd64'
				;;
				
			esac
		;;
		
		SunOS)
			rclone_operating_system=solaris
			
			case "$uname_architecture" in
				
				i86pc)
					rclone_architecture=amd64
				;;
				
				*)
					_put_rclone_on_path_architecture_error 'i86pc'
				;;
				
			esac
		;;
		
		# Plan 9 - unknown uname -s
		
		*)
			exit_system_file_message "Only Darwin, FreeBSD, Linux, NetBSD, OpenBSD and SunOS are known for rclone at this time, not uname -s $uname_operating_system (Plan 9 is unsupported as we do not know its uname -s)"
		;;

	esac
	
	rclone_parent_path="$rclone_root_path"/current/"$rclone_operating_system"/"$rclone_architecture"
}

depends rm
_rclone_command()
{
	# Set generic flags
	# Passwords and interaction
	# Retries flags
	# syslog
	# TLS authentication --ca-cert x --client-cert x --client-key x
#		--syslog --syslog-facility DAEMON --log-level NOTICE \
	set -- \
		--quiet --config "$rclone_temporary_configuration_file_path" --use-mmap --cache-dir "$TMPDIR"/rclone \
		--auto-confirm --progress=false --progress-terminal-title=false \
		--low-level-retries 10 --retries 5 --retries-sleep 500ms \
		"$@"
	
	run_in_new_environment rclone "$tools_folder_path"/rclone "$@"
	# Done as it can contain sensitive passwords.
	rm "$rclone_temporary_configuration_file_path"
}

rclone_sync_copy_or_move()
{
	# Set generic flags
	# Set generic back end flags
	# Set local back end flags
	_rclone_command \
		--check-first --fast-list \
		--links --one-file-system \
		--local-case-sensitive --local-no-check-updated --local-no-set-modtime \
		"$@"
	
}

rclone_sync()
{
	rclone_sync_copy_or_move sync --create-empty-src-dirs "$@"
}

rclone_copy()
{
	rclone_sync_copy_or_move sync --create-empty-src-dirs "$@"
}

rclone_move()
{
	rclone_sync_copy_or_move sync --create-empty-src-dirs --delete-empty-src-dirs "$@"
}

rclone_obscure_password()
{
	rclone_refresh_temporary_configuration_file
	
	local password="$1"
	printf '%s' "$password" | _rclone_command obscure password 2>/dev/null
}

# format is a string of parameters to control the listing:-
#
# p  path
# s  size
# t  modification time
# h  hash
# i  ID of object
# o  Original ID of underlying object
# m  MimeType of object if known
# e  encrypted name
# T  tier of storage if known, e.g. "Hot" or "Cool"
#
# We use a tab as a separator rather than the default semicolon.
rclone_list()
{
	local format="$1"
	local leading_slash="$2"
	local trailing_folder_slash="$3"
	local recursive="$4"
	shift 4
	
	_rclone_command \
		lsf --format "$format" --separator $'\t' --absolute="$leading_slash" --dir-slash="$trailing_folder_slash" --recursive="$recursive" \
		"$@"
}

rclone_list_folders()
{
	local format="$1"
	local leading_slash="$2"
	local trailing_folder_slash="$3"
	local recursive="$4"
	shift 4
	
	rclone_list "$format" "$leading_slash" "$trailing_folder_slash" "$recursive" --dirs-only "$@"
}

depends sort rm
rclone_sorted_remote_backup_folders()
{
	local remote_and_folder_path="$1"
	
	local unsorted_remote_backup_folders_list_file_path="$TMPDIR"/unsorted-remote-backups-folders.list
	sorted_remote_backup_folders_list_file_path="$TMPDIR"/sorted-remote-backups-folders.list
	
	printf '' >"$unsorted_remote_backup_folders_list_file_path"
	set +e
		# If remote folder path missing, fails with exit code 3.
		rclone_list_folders 'p' false false false "$remote_and_folder_path" 2>/dev/null >>"$unsorted_remote_backup_folders_list_file_path"
	set -e
	
	sort -u -r "$unsorted_remote_backup_folders_list_file_path" >"$sorted_remote_backup_folders_list_file_path"
	
	rm "$unsorted_remote_backup_folders_list_file_path"
}

depends head rm
rclone_most_recent_folder()
{
	local remote_and_folder_path="$1"
	
	local sorted_remote_backup_folders_list_file_path
	rclone_sorted_remote_backup_folders "$remote_and_folder_path"
	
	most_recent="$(head -n 1 "$sorted_remote_backup_folders_list_file_path")"
	
	rm "$sorted_remote_backup_folders_list_file_path"
}

rclone_set_rclone_configuration_file_path()
{
	local local_rclone_configuration_file_path="$configuration_folder_path"/rclone.conf
	local is_usable
	file_is_usable "$local_rclone_configuration_file_path"
	if $is_usable; then
		rclone_configuration_file_path="$local_rclone_configuration_file_path"
	else
		cd ~ 1>/dev/null 2>/dev/null
			local user_rclone_configuration_file_path="$(pwd)"/.config/rclone/rclone.conf
		cd - 1>/dev/null 2>/dev/null
		file_is_usable "$user_rclone_configuration_file_path"
		if $is_usable; then
			rclone_configuration_file_path="$user_rclone_configuration_file_path"
		else
			exit_if_configuration_file_missing "Missing rclone configuration file"
		fi
	fi
	
	rclone_configuration_folder_path="${rclone_configuration_file_path%/*}"
}

rclone_environment_variable_expression()
{
	printf '%s' 's;\${RCLONE_CONFIG_DIR};'"$rclone_configuration_folder_path"';g'
}

depends rm sed
rclone_refresh_temporary_configuration_file()
{
	rm -rf "$rclone_temporary_configuration_file_path"

	local rclone_configuration_file_path
	local rclone_configuration_folder_path
	rclone_set_rclone_configuration_file_path
	
	sed -e "$(rclone_environment_variable_expression)" "$rclone_configuration_file_path" >"$rclone_temporary_configuration_file_path"
}

rclone_prefix_remote_path()
{
	local full_remote_path="$1"
	printf '%s' "${configured_remote}${configured_remote_suffix}${full_remote_path}"
}

depends cat
rclone_create_encrypted_remote()
{
	local remote_name="$1"
	local full_remote_path="$2"
	
	local remote="$(rclone_prefix_remote_path "$full_remote_path")"
	cat >>"$rclone_temporary_configuration_file_path" <<-EOF
		[${remote_name}]
		type = crypt
		remote = ${remote}
		filename_encryption = standard
		directory_name_encryption = true
		password = ${configured_obscured_password}
		password2 = ${configured_obscured_salt}
	EOF
}

rclone_default_user()
{
	local default_user
	# This defaults to $USER then $LOGNAME, to match rclone (using $LOGNAME is undocumented)
	if [ "${USER+set}" = 'set' ]; then
		default_user="$USER"
	else
		if [ "${LOGNAME+set}" = 'set' ]; then
			default_user="$LOGNAME"
		else
			default_user=''
		fi
	fi
	
	printf '%s' "$default_user"
}

# Sets the variables 'user', 'host', 'port' and 'known_hosts_file'.
depends sed grep
rclone_read_sftp_configuration()
{
	local rclone_configuration_file_path
	local rclone_configuration_folder_path
	rclone_set_rclone_configuration_file_path
	
	local normalized_configuration_file_path="$TMPDIR"/normalized.rclone.conf
	# Strip leading whitespace
	# Strip trailing whitespace
	# Remove empty lines
	# Remove lines starting with '#'
	# Remove lines starting with ';'
	# Remove whitespace between keys and values.
	# Remove double quotes around values.
	# Remove RCLONE_CONFIG_DIR variable.
	sed \
		-e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g' \
		-e '/^$/d' \
		-e '/^#/d' \
		-e '/^;/d' \
		-e 's/^\([a-z0-9_]*\)[[:space:]]*=[[:space:]]*/\1=/g' \
		-e 's/^\([a-z0-9_]*\)="\(.*\)"/\1=\2/g' \
		-e "$(rclone_environment_variable_expression)" \
		"$rclone_configuration_file_path" >"$normalized_configuration_file_path"
	
	# Ensures that POSIX shell read will read the last line.
	printf '\n' >>"$normalized_configuration_file_path"
	
	# NOTE: grep returns exit code 1 if count is zero.
	set +e
		local desired_section_count="$(grep -c -m 2 '^\[remote\]$' "$normalized_configuration_file_path")"
	set -e
	
	case $desired_section_count in
		
		0)
			exit_configuration_message "The rclone configuration file $rclone_configuration_file_path does not contain the remote $configured_remote"
		;;
		
		1)
			:
		;;
			
		2)
			exit_configuration_message "The rclone configuration file $rclone_configuration_file_path contains the remote $configured_remote more than once"
		;;
		
		*)
			:
		;;
		
	esac
	
	local have_parsed_desired_section=false
	local have_parsed_type=false
	local have_parsed_host=false
	local parsed_host
	local have_parsed_user=false
	local parsed_user
	local have_parsed_port=false
	local parsed_port
	local have_parsed_known_hosts_file=false
	local parsed_known_hosts_file
	
	local key
	local value
	while IFS='=' read -r key value
	do
		if [ -z "$value" ]; then
			# Is this the start of a section?
			if [ "$(first_character "$key")$(last_character  "$key")" = '[]' ]; then
				
				if $have_parsed_desired_section; then
					break
				fi
				
				if [ "$key" = "[${configured_remote}]" ]; then
					have_parsed_desired_section=true
				fi
				
				continue
			fi
		fi
		
		if $have_parsed_desired_section; then
			case "$key" in
			
				type)
					if $have_parsed_type; then
						exit_configuration_message "The rclone configuration file $rclone_configuration_file_path remote $configured_remote contains a duplicate type key"
					fi
					have_parsed_type=true
					
					if [ "$value" != 'sftp' ]; then
						exit_configuration_message "The rclone configuration file $rclone_configuration_file_path remote $configured_remote does not have a type of sftp"
					fi
				;;
			
				host)
					if $have_parsed_host; then
						exit_configuration_message "The rclone configuration file $rclone_configuration_file_path remote $configured_remote contains a duplicate host key"
					fi
					have_parsed_host=true
					
					parsed_host="$value"
				;;
			
				user)
					if $have_parsed_user; then
						exit_configuration_message "The rclone configuration file $rclone_configuration_file_path remote $configured_remote contains a duplicate user key"
					fi
					have_parsed_user=true
					
					parsed_user="$value"
				;;
				
				port)
					if $have_parsed_port; then
						exit_configuration_message "The rclone configuration file $rclone_configuration_file_path remote $configured_remote contains a duplicate port key"
					fi
					have_parsed_port=true
					
					parsed_port="$value"
				;;
				
				known_hosts_file)
					if $have_parsed_known_hosts_file; then
						exit_configuration_message "The rclone configuration file $rclone_configuration_file_path remote $configured_remote contains a duplicate known_hosts_file key"
					fi
					have_parsed_known_hosts_file=true
					
					parsed_known_hosts_file="$value"
				;;
			
				*)
					:
				;;
				
			esac	
		fi
	done <"$normalized_configuration_file_path"
	
	if ! $have_parsed_type; then
		exit_configuration_message "The rclone configuration file $rclone_configuration_file_path remote $configured_remote does not contain a type key"
	fi
	if $have_parsed_host; then
		host="$parsed_host"
	else
		exit_configuration_message "The rclone configuration file $rclone_configuration_file_path remote $configured_remote does not contain a host key"
	fi
	if $have_parsed_user; then
		user="$parsed_user"
	else
		user="$(rclone_default_user)"
	fi
	if $have_parsed_port; then
		port="$parsed_port"
	else
		port=22
	fi
	if $have_parsed_known_hosts_file; then
		known_hosts_file="$parsed_known_hosts_file"
	else
		cd ~ 1>/dev/null 2>/dev/null
			known_hosts_file="$(pwd)"/.ssh/known_hosts
		cd - 1>/dev/null 2>/dev/null
	fi
}
