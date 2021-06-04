# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


set_rclone_root_path()
{
	rclone_root_path="$(pwd)"/tools/rclone
}

depends readlink
set_rclone_version()
{
	rclone_current_path="$rclone_root_path"/current
	exit_if_symlink_missing "$rclone_current_path"
	
	rclone_version="$(readlink "$rclone_current_path")"
}

depends uname
put_rclone_on_path()
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
	
	export PATH="$rclone_root_path"/current/"$rclone_operating_system"/"$rclone_architecture":"$PATH"
}
