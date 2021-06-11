# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


_security_password()
{
	local is_password_or_salt="$1"
	local verb="$2"
	shift 1
	
	local our_account
	local our_service
	local our_kind
	local our_comment
	local our_generic_attribute
	local our_label
	local our_creator
	local our_type
	_security_set_properties "$is_password_or_salt"
	
	security -q "$verb" -a "$our_account" -c "$our_creator" -C "$our_type" -D "$our_kind" -G "$our_generic_attribute" -j "$our_comment" -l "$our_label" -s "$our_service" "$@"
}

_security_set_properties()
{
	local is_password_or_salt="$1"
	
	if $is_password_or_salt; then
		local description='password'
	else
		local description='salt'
	fi
	
	our_account='os-x-backup'
	
	# This what Keychain Access calls 'Kind'.
	# Common options are:-
	# * application password
	# * Web form password
	# * AirPort network password
	# * Internet password
	# * encrypted volume password
	# * IPSec XAuth Password
	our_kind="application $description"
	
	our_generic_attribute="$description"
	
	# This what Keychain Access calls 'Comments'.
	our_comment="$description used to access an os-x-backup encrypted remote called $configured_remote"
	
	# This what Keychain Access calls 'Name'.
	our_label="$_program_name remote $configured_remote ($description)"
	
	# This is what Keychain Access calls 'Where'.
	our_service="$_program_name remote $configured_remote"
	
	# 4-digit-code.
	our_creator='1234'
	
	# 4-digit-code.
	our_type='5678'
}

# Adds to the 'login' keychain by default.
security_add_password()
{
	local is_password_or_salt="$1"
	
	# We use the default keychain
	# Other keychains are login, System and Local Items
	_security_password "$is_password_or_salt" add-generic-password -w
}

# Updates in the 'login' keychain by default.
security_update_password()
{
	local is_password_or_salt="$1"
	
	# We use the default keychain
	# Other keychains are login, System and Local Items
	_security_password "$is_password_or_salt" add-generic-password -U -w
}

# Gets from the 'login' keychain by default.
# Returns code '44' if absent.
security_get_password()
{
	local is_password_or_salt="$1"
	
	_security_password "$is_password_or_salt" find-generic-password -w 2>/dev/null
}

# Deletes from the 'login' keychain by default.
security_delete_password()
{
	local is_password_or_salt="$1"
	
	_security_password "$is_password_or_salt" delete-generic-password 1>/dev/null
}

security_get_or_create_password()
{
	local is_password_or_salt="$1"
	
	set +e
		password="$(security_get_password "$is_password_or_salt")"
		local exit_code=$?
	set -e
	
	if [ $exit_code -eq 0 ]; then
		return 0
	fi
	
	security_add_password "$is_password_or_salt"
	password="$(security_get_password "$is_password_or_salt")"
}
