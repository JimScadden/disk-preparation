# Files

Here you find both needed files and examples to be inspired by.

## Needed files

### disk-preparation

A file named `disk-preparation` should be palaced together with the preseed file.
The `postinst` script in `disk-preparation_1.0_all.udeb` will download the
`disk-preparation` script/program and run it. The file here is just a placeholder file
That doesn't do anything except writeing some log messages to `/var/log/syslog`.

An alternative is `disk-prep-wrapper.sh found below.

### disk-preparation_1.0_all.udeb

This is a very small `udeb` package with just the `control` and `postinst` files.
The control file adds the postinst file to the installer system. This package is
built by the commands describied in the parent folder's README.md.

## Optional files

### early-wrapper.sh

Depending on setup of `early_command` in the `preseed` file, this file may be needed.

### disk-prep-wrapper.sh

A wrapper script much like `early-wrapper.sh` used to download and run other script(s)
to do all the nice stuff before or as replacement to partman.

This wrapper script get the list of scripts to download from preseed, e.g.:
```bash
d-i my-stuff/disk-prep-wrapper/prepscripts string find-disks.sh setup-disks.sh prep-stop.sh
```
### prep-stop.sh

Just a small helper script that pauses the installation (if the debconf priority is `high`
or lower) and displays a note before partman is lanuched.
