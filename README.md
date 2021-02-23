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

### Configuration

The `udeb` downloader extracts the `preseed` file location from the
boot command line.  It downloads and executes a script named
`disk-preparation` from the same location as the `preseed` file.

```bash
# sed -n 's#.*url=\([^ ]\+/\).*#\1#p' /proc/cmdline
```

The disk-preparation `udeb`package can be downloaded and run from
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


### Script Example

For the moment I recommend a look at the original repo:<br/>
<https://github.com/bfritz/remote-script-partitioner#script-example>
