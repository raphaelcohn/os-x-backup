# This file is part of os-x-backup. It is subject to the license terms in the COPYRIGHT file found in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT. No part of os-x-backup, including this file, may be copied, modified, propagated, or distributed except according to the terms contained in the COPYRIGHT file.
# Copyright © 2021 The developers of os-x-backup. See the COPYRIGHT file in the top-level directory of this distribution and at https://raw.githubusercontent.com/raphaelcohn/os-x-backup/master/COPYRIGHT.


# use_rsync
#
# Set this to enable the use of rsync rather than rclone.
#
# Valid values are 'true' or 'false'
# Default value is 'false'.
#
# Set to 'true' to use rsync.
# This is only needed if using link_dest='backup_kind'.
#
# This does not work with encryption.
#
#use_rsync='false'


# backup_kind
#
# Type of backup to perform.
#
# Valid values are 'full', 'replaced', 'copy_dest', 'link_dest', 'differential' or 'incremental'.
#
# Default value is 'copy_dest'.
#
# NOTE: 'link_dest' only works if use_rsync='true' (see below).
#
#backup_kind='copy_dest'


# remote
#
# Override the remote in use.
#
# Valid values are one of:-
#
# * Start with a leading slash '/' for a local copy, and are interpreted as an extant path on the local machine (it is not created).
# * Do not start with a leading slash '/' but are not empty, in which case they are either:-
#	* A remote in `~/os-x-backup/rclone.conf` if use_rsync='false' (without a trailing colon).
#	* A 'Host' alias entry in `~/os-x-backup/rsync.ssh_config` if use_rsync='true' (without a trailing colon).
# * Are empty, in which case the folder containing the 'os-x-backup' binary is used.
#
# Valid values MUST NOT start or end with a colon ':'.
#
# Default value is 'remote'.
#
# This should be a rclone backend in 'rclone.conf' (as '[remote]') or a 'Host remote' in rsync.ssh_config.
#
#remote='remote'


# remote_path_prefix
#
# A path to prefix before synchronizing.
#
# Default value is 'backups'.
#
# Can be relative or absolute (starts with a leading slash '/').
# Must not be absolute if the remote (above) is empty or starts with a leading slash '/'.
#
#remote_path_prefix='backups'
