# Overview

`os-x-backup` uses macOS APFS snapshots to do offsite, client-side encrypted\* backups. It is optimized to back up to `rsync.net`, but could (with tweaks) use any backend supported by `rclone`. It can fallback to using `rsync`. It requires no programs to be installed on macOS, and relies on the standard Apple-shipped utilities.

As APFS snapshots are highly restricted on macOS, `os-x-backup` has to use Time Machine to create them. This means backups are influenced by your Time Machine configuration. It emerged when I discovered I couldn't easily send Time Machine backups to a SFTP remote.

\* Not when using `rsync`.


## Usage

This program is entirely self-contained. It does not need to be installed.

Clone the repository from git, or download and extract a release tarball, eg

```
git clone https://github.com/raphaelcohn/os-x-backup
cd os-x-backup
./os-x-backup help
```

The program does need to be able to create a writable folder `temporary` inside its root (`os-x-backup/`). The reason for this is to ensure that any sensitive data is kept local to the user and there is no dependency on a temporary partition or a potential Time-of-Check-Time-of-Use (TOCTOU) security vulnerability. This may change in the future.


## Using with (rsync.net)[https://rsync.net]

As a one off, run the following:-

```
cd tools
./install-rclone-configuration-for-rsync-net install [my rclone user name]
./create-and-install-ssh-key
```

This will securely authenticate the rsync.net SSH key fingerprints, generate a `known_hosts` file and create a template configuration in `/.config/os-x-backup`. This will also create a SSH certificate authority in `~/.config/os-x-backup-certificate-authority`.


## Configuration

Ordinarily, configuration for `os-x-backup` is stored in `~/.config/os-x-backup`. To override the use of `~/.config/os-x-backup` as the location of configuration, one can set the environment variable `OS_X_BACKUP_CONFIGURATION_FOLDER_PATH`. The remainder of configuration is stored using Time Machine and Keychain Access. If the variable `XDG_CONFIG_HOME` is set but `OS_X_BACKUP_CONFIGURATION_FOLDER_PATH` is not set, it replaces the path searched for `os-x-backup`.

This folder can contain a number of files and folders, but the minimum typical content is as follows:-

```
rclone.conf
root/
```

Typically `rclone.conf` is a rclone configuration file containing one backend remote, called `remote`. `root` is a folder.

Conceptually, configuration can be divided into 4 places:-

* Configuration in Time Machine
* Configuration in Keychain Access
* Configuration folders
* Configuration files

This may be simpler to understand by browsing the `example-configuration` folder in source control.


### Configuration in Time Machine

`os-x-backup` uses the list of volumes that Time Machine has been configured to manage (eg `/`, `/Volumes/BigDisk`, etc). Volumes are never explicitly configured in Time Machine; they are the result of the folders Time Machine has been configured to manage.

Each volume's path is converted into a name by replacing slashes, eg `/Volumes/BigDisk` becomes `Volumes_BigDisk`. The volume `/` is given the special name `root`. A leading slash `/` is removed.


### Configuration in Keychain Access

`os-x-backup` stores encryption passwords and salts using Keychain Access. These are created on-the-fly when `os-x-backup` is first run - you will be prompted for two 'passwords'.


### Configuration folders

Each configuration folder stores the configuration for a volume Time Machine manages (see above). Each configuration folder's name is the same as the volume name as converted above, with the exception of `root`, for `/`.

Inside each configuration folder is a sample folder hierarchy, eg `Users/raph/Desktop`. Each of these hierarchies maps a folder structure to back up.

At the leaf of the configuration folder, an optional filter file can exist. If using `rclone`, this is called `filter.rclone` and is a standard `rclone` filter file. The root for `rclone`'s purposes will be the leaf folder (eg to exclude a dot folder `~/.cargo` in `/Users/me`, have an entry `- /.cargo/**`). If using `rsync`, this is an included `rsync` filter file.


### Configuration files

* For `rclone` and `rsync`
	* `configuration.sh`
	* `known_hosts`
* SSH keys and certificates (eg `id_rsa`).
* For `rclone`
	* `rclone.conf`
	* `rclone.environment.sh`
* For `rsync`
	* `rsync.environment.sh`
	* `ssh_config`


#### `configuration.sh`

This file is optional.

This is a piece of shell script sourced before configuration to provide overrides to common configuration. It provides settings for local (internal) environment variables. If missing, then the environment variables are assigned their default values. The environment variables are:-

* `use_rsync`
* `backup_kind`
* `remote`
* `remote_path_prefix`

All of these environment variables are unset at the time the configuration is sourced. None of these environment variables are ever exported and aren't available to any scripts or programs `os-x-backup` runs.


##### `use_rsync`

* Set this to enable the use of `rsync` rather than `rclone`.
* Valid values are `true` or `false`.
* Default value if unset is `false`.
* Example: `use_rsync=true`.

Instead of using the bundled `rclone`, the system's default copy of `rsync` can be used. This supports an additional `backup_kind`, called `link_dest`, but does not support encryption.


##### `backup_kind`

* Set this to change the type of backup to perform
* Valid values are `full`, `replaced`, `copy_dest`, `link_dest`, `differential` or `incremental`.
* Default value if unset is `copy_dest`.
* Example: `backup_kind=link_dest`.

At this time, only the values `full`, `copy_dest` and `link_dest` are actually properly supported. The other settings partly work but do not satisfactorily work with encryption.

The `link_dest` value can only be specified if `use_rsync=true`.


###### `remote`

* Set this value to change the remote storage backend using by `rclone`, or the aliased line used by `rsync` for a SSH `Host` line.
* Valid values can not start or end with a colon.
* Default value if unset is `remote`.
* Example: `remote=my_backup_host`.

There is very little reason to override this value unless using a `rclone.conf` file shared with other applications or usages.


#####  `remote_path_prefix`

* Set this to change the path backups will exist under.
* Valid values are anything supported by the remote backup, but must not end with a trailing slash `/`.
* Default value is `backups`.
* Example: `remote_path_prefix=archives`.

This value can be empty (`remote_path_prefix=''`). It can be relative or absolute (ie starts with a leading slash `/`). It can include subfolders (eg `backups/desktops`). Unless using `rsync`, it's unlikely that this value should be absolute.


#### `known_hosts`

This file is optional but recommended.

It allows a known, good override of `known_hosts` when using SFTP remote backends with `clone` or SSH with `rsync`, so only the host necessary for backup is used.

To make use of it in an `rclone` configuration file, do the following:-

```

[remote]
type = sftp
...
known_hosts_file = "${RCLONE_CONFIG_DIR}/known_hosts"
```

To use it for `rsync`, add it to `rsync.ssh_config` with a configuration stanza like:-

```

Host remote
	...
	UserKnownHostsFile ~/.config/os-x-backup/known_hosts
```


#### `rclone.conf`

This file is optional.

If absent, then the normal rclone default configuration file at `~/.config/rclone/rclone.conf` is used. If that is missing, then an error happens and backup fails.

This file should ordinarily contain at least one remote, called (unless overridden by the configuration environment variable `remote`), `remote`.


#### `rclone.environment.sh`

This file is optional.

It is unlikely it will be needed. By default, when the backup executes `rclone`, it does so in a pristine environment; no environment variables (not even `PATH`) are specified. If there is a need to use other environment variables (eg `rclone` can use `USER` or `LOGNAME`), then this file permits that. One use case is to add very specific overrides to the command line the backup passes to `rclone`, using environment variables that start `RCLONE_`.

This file is sourced by the shell running os-x-backup if it exists before each execution of `rclone`.

To add environment variables, add stanzas of the following form:-

```
export PATH=/path/to/bin:/other/path/to/bin
export USER=myotherusername
```


#### `rsync.environment.sh`

This file is optional.

It is highly unlikely it will be needed. By default, when the backup executes `rsync` (and it does so only if `use_rsync=true`), it does so in a pristine environment; no environment variables (not even `PATH`) are specified. See the information given for `rclone.environment.sh` as to how it can be used.


#### `ssh_config`

This file is optional but recommended if using `rsync` (`rsync=true`).

It works similarly to `rclone.conf`, and, if present, overrides the use of `~/.ssh/ssh_config`. Typically, it will contain specific key algorithm, key location and `known_hosts` locations for a remote `Host` in the file under the entry `Host remote`.


## Environment Variables

To override the use of `~/.config/os-x-backup` as the location of configuration, one can set the environment variable `OS_X_BACKUP_CONFIGURATION_FOLDER_PATH`.


## Weaknesses

Time Machine is permitted to clean up APFS snapshots at any time. Consequently, there is a window of opportunity in which a Time Machine generated APFS snapshot can be deleted after we have requested it but before we can use it.


## License

This software and example configuration, assets and other files is licensed using the MIT license. Please see the `COPYRIGHT` file for its full terms.
