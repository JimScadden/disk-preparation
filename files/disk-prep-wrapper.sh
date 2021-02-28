#!/bin/sh
# Copyright (c) 2021, Magnus Sandberg
# BSD 2-Clause "Simplified" License

### Installation
## 1) Rename this file to 'disk-preparation' and place it together with preseed file
##
## 2) Add the following two lines to your preseed file, remove comment on the second line,
##    update with correct script(s) to run. prep-stop.sh can help while developing real script(s).
# Additional scripts to run from disk-preparation script:
#d-i my-stuff/disk-prep-wrapper/prepscripts string find-disks.sh setup-disks.sh prep-stop.sh

set -e

MYTAG="my-stuff"
DLPATH="/tmp/my-stuff"
MYNAME="disk-prep-wrapper"
logger -t "$MYTAG" "$0 started by postinst."

# Create a template file, for our progress information
cat > $DLPATH/$MYNAME.template <<EOT
Template: $MYTAG/$MYNAME/progress/title
Type: text
Description: ${MYNAME}: preparing disks

Template: $MYTAG/$MYNAME/progress/backupself
Type: text
Description: Making backup of $0

Template: $MYTAG/$MYNAME/progress/prepscripts
Type: text
Description: Getting script(s) from preseed

Template: $MYTAG/$MYNAME/progress/noscripts
Type: text
Description: No script(s) found in preseed, exiting

Template: $MYTAG/$MYNAME/progress/showscripts
Type: text
Description: The following scipts(s) configured in preseed: \${scripts}

Template: $MYTAG/$MYNAME/progress/checkcmdline
Type: text
Description: Checking /proc/cmdline to figure out download method and path

Template: $MYTAG/$MYNAME/progress/dlscript
Type: text
Description: Downloading \${scriptname}

Template: $MYTAG/$MYNAME/progress/execscript
Type: text
Description: Starting \${scriptname}

Template: $MYTAG/$MYNAME/progress/scriptsdone
Type: text
Description: All prep script(s) done

Template: $MYTAG/$MYNAME/progress/end
Type: text
Description: Done!
EOT
logger -t "$MYTAG" "Template create in $DLPATH/$MYNAME.template"

# Load functions etc
. /usr/share/debconf/confmodule
logger -t "$MYTAG" "Debconf confmodule functions loaded."

db_version 2.0

# Load your template
debconf-loadtemplate $MYTAG $DLPATH/$MYNAME.template
logger -t "$MYTAG" "Debconf template loaded."

STEPS=7
db_progress START 0 $STEPS $MYTAG/$MYNAME/progress/title
logger -t "$MYTAG" "db_progress START with $STEPS steps."
db_progress INFO $MYTAG/$MYNAME/progress/backupself || logger -t "$MYTAG" "db_progress INFO backupself failed."

db_progress STEP 1 || logger -t "$MYTAG" "db_progess STEP before backupself failed."
cp $0 $DLPATH/ && logger -t "$MYTAG" "Backup of $0 done." || logger -t "$MYTAG" "Backup of $0 failed."

db_progress STEP 1 || logger -t "$MYTAG" "db_progess STEP before get prepscripts failed."
db_progress INFO $MYTAG/$MYNAME/progress/prepscripts || logger -t "$MYTAG" "db_progress INFO prepscripts failed."
db_get $MYTAG/$MYNAME/prepscripts && RC=$? || RC=$?
if [ $RC -gt 0 ] ; then
    logger -t "$MYTAG" "db_get prepscripts failed. Option not found,"
    logger -t "$MYTAG" "continuing without disk-preparation script(s)."

    db_progress STEP 1 || logger -t "$MYTAG" "db_progess STEP before noscripts failed."
    db_progress INFO $MYTAG/$MYNAME/progress/noscripts || logger -t "$MYTAG" "db_progress INFO noscripts failed."
else
    prepscripts="$RET"
    count=$( echo $prepscripts | wc -w )
    logger -t "$MYTAG" "Prep-scripts from preseed: $prepscripts"

    db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before showscripts failed."
    db_subst $MYTAG/$MYNAME/progress/showscripts scripts "$prepscripts" || logger -t "$MYTAG" "db_subst update of template with prepscript(s) to run failed."
    db_progress INFO $MYTAG/$MYNAME/progress/showscripts || logger -t "$MYTAG" "db_progress INFO showscripts failed."

    db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before checkcmdline failed."
    db_progress INFO $MYTAG/$MYNAME/progress/checkcmdline || logger -t "$MYTAG" "db_progress INFO checkcmdline failed."

    DLURL=$( sed -n 's#.*url=\([^ ]\+/\).*#\1#p' /proc/cmdline )
    logger -t "$MYTAG" "DLURL extracted from /proc/cmdline: $DLURL"
    DLMETHOD=$( echo $DLURL | cut -d':' -f1 | tr 'a-z' 'A-Z' )
    logger -t "$MYTAG" "DLMETHOD extracted from \$DLURL: $DLMETHOD"
    if [ "x$DLMETHOD" = "xTFTP" ] ; then
	PARTS=$( echo $DLURL | sed -n 's#.*//\([^/]\+\)/\(.*\)$#\1:\2#p' )
	DLHOST=$( echo $PARTS | cut -d':' -f1 )
	logger -t "$MYTAG" "TFTP server: $DLHOST"
	DLURL=$( echo $PARTS | cut -d':' -f2 )
	logger -t "$MYTAG" "Server path: $DLURL"
    fi

    db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before script(s) loop failed."
    for script in $prepscripts ; do
	logger -t "$MYTAG" "Prep script: $script"

	db_subst $MYTAG/$MYNAME/progress/dlscript scriptname $script || logger -t "$MYTAG" "  db_subst update of template with script to download failed."
	db_progress INFO $MYTAG/$MYNAME/progress/dlscript || logger -t "$MYTAG" "  Show dlscript failed."
	if [ "x$DLMETHOD" = "xTFTP" ] ; then
	    logger -t "$MYTAG" "  Downloading $script using tftp command."
	    tftp -l $DLPATH/$script -g $DLHOST -r $DLURL/$script || exit $?
	else
	    logger -t "$MYTAG" "  Downloading $script using wget command."
	    wget -P $DLPATH/ ${DLURL}/$script || exit $?
	fi

	db_subst $MYTAG/$MYNAME/progress/execscript scriptname $script || logger -t "$MYTAG" "  db_subst update of template with script to run failed."
	db_progress INFO $MYTAG/$MYNAME/progress/execscript || logger -t "$MYTAG" "  Show execscript failed."

	logger -t "$MYTAG" "  Starting $script"
	# Passing $MYTAG to scripts
	chmod +x $DLPATH/$script && $DLPATH/$script $MYTAG || exit $?

	db_progress START 0 $STEPS $MYTAG/$MYNAME/progress/title && logger -t "$MYTAG" "  db_progress START (restarting) during prepscripts."
	db_progress SET 5 || logger -t "$MYTAG" "  db_progress SET during prepscripts failed."
    done

    db_progress STEP 1 || logger -t "$MYTAG" "Stepping after prep-scirpts failed."
    db_progress INFO $MYTAG/$MYNAME/progress/scriptsdone || logger -t "$MYTAG" "db_progress INFO scriptsdone failed."
fi
db_progress SET 7 || logger -t "$MYTAG" "db_progress SET before end failed."
db_progress INFO $MYTAG/$MYNAME/progress/end || logger -t "$MYTAG" "db_progress INFO end failed."

db_progress STOP && logger -t "$MYTAG" "db_progress STOP done." || logger -t "$MYTAG" "db_progress STOP failed."
logger -t "$MYTAG" "End of ${MYNAME}.sh"
exit 0
