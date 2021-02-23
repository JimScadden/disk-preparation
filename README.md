# Disk Preparation

Partition Debian disks with PXE and shell script instead of complex
preseed templates.

Advanced partitioning of Debian boxes with preseed templates can be a
challange. `disk-preparation` makes it easy to bypass or extend the built-in
templates and write a shell script to prepare or partition your disks.

It is possible to disable `partman` in the Debian installer, downloads
your `preparation` script via TFTP or HTTP(S) and execute it.

### Building

Packages are built with `debhelper`'s `dh_builddeb`.

```bash
$ dh_builddeb
```

### Boot information during install

Switch to a shell terminal during installation, e.g.: `CTRL-F2`.

```bash
$ sed -n 's#.*url=\([^ ]\+/\).*#\1#p' /proc/cmdline
```

### Configuration

The `udeb` downloader extracts the `preseed` file location from the
boot command line.  It downloads and executes a script named
`disk-preparation` from the same location as the `preseed` file.


The disk-preparation `udeb` package can be downloaded and added from
`preseed/early_command`, e.g.:

```bash
d-i preseed/early_command string                                          \
    MYTAG="my-early_command" ; pkgname="disk-preparation_1.0_all.udeb" ;  \
    DLURL=$( sed -n 's#.*url=\([^ ]\+/\).*#\1#p' /proc/cmdline ) &&       \
    logger -t "$MYTAG" "DLURL extracted from /proc/cmdline: $DLURL" &&    \
    DLMETHOD=$( echo $DLURL | cut -d':' -f1 | tr 'a-z' 'A-Z' ) &&         \
    logger -t "$MYTAG" "DLMETHOD extracted from \$DLURL: $DLMETHOD" &&    \
    DLPATH="/tmp/my-stuff" && mkdir $DLPATH &&                            \
    if [ "x$DLMETHOD" = "xTFTP" ] ; then                                  \
      PRT=$( echo $DLURL | sed -n 's#.*//\([^/]\+\)/\(.*\)$#\1:\2#p' ) && \
      DLHOST=$( echo $PRT | cut -d':' -f1 ) &&                            \
      logger -t "$MYTAG" "TFTP server: $DLHOST" &&                        \
      DLURL=$( echo $PRT | cut -d':' -f2 ) &&                             \
      logger -t "$MYTAG" "Server path: $DLURL" &&                         \
      logger -t "$MYTAG" "Downloading $pkgname using tftp command." &&    \
      tftp -l $DLPATH/$pkgname -g $DLHOST -r $DLURL/$pkgname || exit $? ; \
    else                                                                  \
      logger -t "$MYTAG" "Downloading $pkgname using wget command." &&    \
      wget -P $DLPATH/ $DLURL/$pkgname | exit $? ;                        \
    fi ;                                                                  \
    logger -t "$MYTAG" "Adding $pkgname to the installer system." &&      \
    udpkg --unpack $DLPATH/$pkgname &&                                    \
    logger -t "$MYTAG" "End of early_command, continuing the installation."
```

Or use the `early-wrapper.sh` script from preseed to be able to change
debconf priority, add the `udeb` to the Installer system, run additional
scripts as soon as possible:

```bash
d-i preseed/early_command string                                           \
    MYTAG="my-early_command" ; escript="early-wrapper.sh" ;                \
    export DLURL=$( sed -n 's#.*url=\([^ ]\+/\).*#\1#p' /proc/cmdline ) && \
    logger -t "$MYTAG" "DLURL extracted from /proc/cmdline: $DLURL" &&     \
    export DLMETHOD=$( echo $DLURL | cut -d':' -f1 | tr 'a-z' 'A-Z' ) &&   \
    logger -t "$MYTAG" "DLMETHOD extracted from \$DLURL: $DLMETHOD" &&     \
    export DLPATH="/tmp/my-stuff" && mkdir $DLPATH &&                      \
    if [ "x$DLMETHOD" = "xTFTP" ] ; then                                   \
      PRT=$( echo $DLURL | sed -n 's#.*//\([^/]\+\)/\(.*\)$#\1:\2#p' ) &&  \
      export DLHOST=$( echo $PRT | cut -d':' -f1 ) &&                      \
      logger -t "$MYTAG" "TFTP server: $DLHOST" &&                         \
      export DLURL=$( echo $PRT | cut -d':' -f2 ) &&                       \
      logger -t "$MYTAG" "Server path: $DLURL" &&                          \
      logger -t "$MYTAG" "Downloading $escript using tftp command." &&     \
      tftp -l $DLPATH/$escript -g $DLHOST -r $DLURL/$escript || exit $? ;  \
    else                                                                   \
      logger -t "$MYTAG" "Downloading $escript using wget command." &&     \
      wget -P $DLPATH/ $DLURL/$escript || exit $? ;                        \
    fi ;                                                                   \
    logger -t "$MYTAG" "Starting $escript" &&                              \
    chmod +x $DLPATH/$escript && $DLPATH/$escript &&                       \
    logger -t "$MYTAG" "End of early_command, continuing the installation."

#
# My own d-i varaibles used by early-wrapper.sh:
# The variable $ MYTAG is set to "my-stuff" in most of my scripts and will be
# used for logger messages and for my own configuration variables in debconf.
#
# The debconf priority we like to continue with after inital network setup.
# To have automated install, "priority=high" is enough after network is
# configured.
# To boot with DHCP and avoid network questions before the preseed file is
# loaded, the boot commandline must have "priority=citical".
# After the inital network config we can change to our preferred priority.
# With "medium" or "low" we will see the installer menus even if options are
# set by the preseed file. Can be used for debugging or updates of preseed file.
d-i my-stuff/early-wrapper/newprio string high
#
# A list of udeb(s) to unpack (add to the installer system).
# Udebs will only be unpacked, not fully installed until relevant stage in
# the installer system depening on 'Installer-Menu-Item' in control file.
d-i my-stuff/early-wrapper/udeb-unpack string disk-preparation_1.0_all.udeb
#
# Additional scripts to run from early-wrapper.sh:
#d-i my-stuff/early-wrapper/earlyscripts string early-extra-1.sh early-extra-2.sh
```

### Disk Preparation Script Example

For the moment I recommend a look at the original repo:<br/>
<https://github.com/bfritz/remote-script-partitioner#script-example>
