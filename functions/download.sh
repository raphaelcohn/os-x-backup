# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


depends curl
download_using_curl()
{
	local url="$1"
	local destination_folder_path="$2"
	local file_name="$3"
	local maximum_tls_version="$4"
	
	# Mac OS X using homebrew has a version of curl that supports TLS 1.3.
	local curl_command='/usr/local/opt/curl/bin/curl'
	if [ -x "$curl_command" ]; then
		local tls_version="$maximum_tls_version"
	else
		curl_command="$(command -v curl)"
		local tls_version=1.2
	fi

	printf 'Downloading %s to %s using curl… ' "$url" "$destination_folder_path" 1>&2
	cd "$destination_folder_path" 1>/dev/null 2>/dev/null
		set +e
			"$curl_command" --silent --fail --proto '=https' --http2 --tlsv${tls_version} --output "$file_name" "$url"
			local exit_code=$?
		set -e
		case $exit_code in
			
			0)
				printf 'done\n' 1>&2
				failed=false
			;;
			
			22)
				printf 'not found\n' 1>&2
				failed=true
			;;
			
			*)
				exit_temporary_fail_message "failed"
			;;
			
		esac
	cd - 1>/dev/null 2>/dev/null
}
