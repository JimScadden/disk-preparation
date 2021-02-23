#!/bin/sh
# Copyright (c) 2021, Magnus Sandberg
# BSD 2-Clause "Simplified" License

set -e

MYTAG="my-stuff"
MYNAME="early-wrapper"
logger -t "$MYTAG" "${MYNAME}.sh started."

# Create a template file, for our progress information
cat > $DLPATH/$MYNAME.template <<EOT
Template: $MYTAG/$MYNAME/progress/title
Type: text
Description: ${MYNAME}: preparing installer system

Template: $MYTAG/$MYNAME/progress/checkpreseed
Type: text
Description: Checking preseed settings

Template: $MYTAG/$MYNAME/progress/preseedprio
Type: text
Description: Get preferred debconf priority from preseed

Template: $MYTAG/$MYNAME/progress/checkprio
Type: text
Description: Checking current debconf priority

#Template: $MYTAG/$MYNAME/progress/bootprio
#Type: text
#Description: Debconf priority from boot: \${bootprio}

Template: $MYTAG/$MYNAME/progress/changeprio
Type: text
Description: Change debconf priority from '\${bootprio}' to '\${newprio}'

Template: $MYTAG/$MYNAME/progress/getudebs
Type: text
Description: Get udeb name(s) to unpack from preseed

Template: $MYTAG/$MYNAME/progress/showudebs
Type: text
Description: The following udeb(s) will be unpacked: \${udebs}

Template: $MYTAG/$MYNAME/progress/dludeb
Type: text
Description: Downloading \${udebname}

Template: $MYTAG/$MYNAME/progress/unpackudeb
Type: text
Description: Adding \${udebname}

Template: $MYTAG/$MYNAME/progress/udebsdone
Type: text
Description: All udeb(s) done

Template: $MYTAG/$MYNAME/progress/earlyscripts
Type: text
Description: Get additional early-scripts from preseed

Template: $MYTAG/$MYNAME/progress/showscripts
Type: text
Description: The following early scipts(s) will be executed: \${scripts}

Template: $MYTAG/$MYNAME/progress/dlscript
Type: text
Description: Downloading \${scriptname}

Template: $MYTAG/$MYNAME/progress/execscript
Type: text
Description: Executing \${scriptname}

Template: $MYTAG/$MYNAME/progress/scriptsdone
Type: text
Description: All early script(s) done

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

STEPS=13
db_progress START 0 $STEPS $MYTAG/$MYNAME/progress/title
logger -t "$MYTAG" "db_progress START with $STEPS steps."
db_progress INFO $MYTAG/$MYNAME/progress/checkpreseed || logger -t "$MYTAG" "db_progress INFO checkpreseed failed."

db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before get preseedprio failed."
db_progress INFO $MYTAG/$MYNAME/progress/preseedprio || logger -t "$MYTAG" "db_progress INFO preseedprio failed."
db_get $MYTAG/$MYNAME/newprio && RC=$? || RC=$?
if [ $RC -gt 0 ] ; then
    logger -t "$MYTAG" "db_get newprio failed. Option not found,"
    logger -t "$MYTAG" "continuing with unchanged priority."
else
    newprio="$RET"
    logger -t "$MYTAG" "New prio from preseed: $newprio"

    db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before checkprio failed."
    db_progress INFO $MYTAG/$MYNAME/progress/checkprio || logger -t "$MYTAG" "db_progress INFO checkprio failed."
    db_get debconf/priority
    bootprio="$RET"
    logger -t "$MYTAG" "Debconf priority from boot: $bootprio"

    if [ "x$bootprio" = "x$newprio" ] ; then
	logger -t "$MYTAG" "New priority same as boot priority."
	logger -t "$MYTAG" "Continuing with unchanged priority."
    else
	db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before update of template failed."
	db_subst $MYTAG/$MYNAME/progress/changeprio bootprio $bootprio || logger -t "$MYTAG" "db_subst update of template with debconf's boot priority failed."
	db_subst $MYTAG/$MYNAME/progress/changeprio newprio $newprio || logger -t "$MYTAG" "db_subst update of template with debconf's new priority failed."
	db_progress INFO $MYTAG/$MYNAME/progress/changeprio || logger -t "$MYTAG" "db_progress INFO changeprio failed."

	db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before set newprio failed."
	db_set debconf/priority $newprio
	db_get debconf/priority
	logger -t "$MYTAG" "Priority now set to: $RET"
    fi
fi

logger -t "$MYTAG" "DLMETHOD set with 'export' in preseed: $DLMETHOD"
if [ "x$DLMETHOD" = "xTFTP" ] ; then
    logger -t "$MYTAG" "TFTP server set with 'export' in preseed: $DLHOST"
    logger -t "$MYTAG" "Server path set with 'export' in preseed: $DLURL"
    logger -t "$MYTAG" "DLPATH set with 'export' in preseed: $DLPATH"
else
    logger -t "$MYTAG" "DLURL set with 'export' in preseed: $DLURL"
    logger -t "$MYTAG" "DLPATH set with 'export' in preseed: $DLPATH"
fi

db_progress SET 5 || logger -t "$MYTAG" "db_progess SET before get udeb-unpack failed."
db_progress INFO $MYTAG/$MYNAME/progress/getudebs || logger -t "$MYTAG" "db_progress INFO getudebs failed."
db_get $MYTAG/$MYNAME/udeb-unpack && RC=$? || RC=$?
if [ $RC -gt 0 ] ; then
    logger -t "$MYTAG" "db_get udeb-unpack failed. Option not found,"
    logger -t "$MYTAG" "continuing without unpack of udeb(s)."
else
    udebs="$RET"
    count=$( echo $udebs | wc -w )
    logger -t "$MYTAG" "Udeb(s) from preseed: $udebs"

    db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before show udeb(s) failed."
    db_subst $MYTAG/$MYNAME/progress/showudebs udebs "$udebs" || logger -t "$MYTAG" "db_subst update of template with udeb(s) to add failed."
    db_progress INFO $MYTAG/$MYNAME/progress/showudebs || logger -t "$MYTAG" "db_progress INFO showudebs failed."

    db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before udeb(s) loop failed."
    for udeb in $udebs ; do
	logger -t "$MYTAG" "Udeb to unpack: $udeb"

	db_subst $MYTAG/$MYNAME/progress/dludeb udebname $udeb || logger -t "$MYTAG" "  db_subst update of template with udeb to download failed."
	db_progress INFO $MYTAG/$MYNAME/progress/dludeb || logger -t "$MYTAG" "  Show dludeb failed."
	if [ "x$DLMETHOD" = "xTFTP" ] ; then
	    logger -t "$MYTAG" "  Downloading $udeb using tftp command."
	    tftp -l $DLPATH/$udeb -g $DLHOST -r $DLURL/$udeb || exit $?
	else
	    logger -t "$MYTAG" "  Downloading $udeb using wget command."
	    wget -P $DLPATH/ $DLURL/$udeb || exit $?
	fi

	db_subst $MYTAG/$MYNAME/progress/unpackudeb udebname $udeb || logger -t "$MYTAG" "  db_subst update of template with udeb to unpack failed."
	db_progress INFO $MYTAG/$MYNAME/progress/unpackudeb || logger -t "$MYTAG" "  Show unpackudeb failed."
	logger -t "$MYTAG" "  Unpacking $udeb"
	udpkg --unpack $DLPATH/$udeb || exit $?
    done
    db_progress STEP 1 || logger -t "$MYTAG" "Stepping after udeb(s) added failed."
    db_progress INFO $MYTAG/$MYNAME/progress/udebsdone || logger -t "$MYTAG" "db_progress INFO udebsdone fialed."
fi

db_progress SET 9 || logger -t "$MYTAG" "db_progess SET before get earlyscripts failed."
db_progress INFO $MYTAG/$MYNAME/progress/earlyscripts || logger -t "$MYTAG" "db_progress INFO earlyscripts failed."
db_get $MYTAG/$MYNAME/earlyscripts && RC=$? || RC=$?
if [ $RC -gt 0 ] ; then
    logger -t "$MYTAG" "db_get earlyscripts failed. Option not found,"
    logger -t "$MYTAG" "continuing without additional script(s)."
else
    earlyscripts="$RET"
    count=$( echo $earlyscripts | wc -w )
    logger -t "$MYTAG" "Early-scripts from preseed: $earlyscripts"

    db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before show earlyscripts failed."
    db_subst $MYTAG/$MYNAME/progress/showscripts scripts "$earlyscripts" || logger -t "$MYTAG" "db_subst update of template with earlyscript(s) to run failed."
    db_progress INFO $MYTAG/$MYNAME/progress/showscripts || logger -t "$MYTAG" "db_progress INFO showscripts failed."

    db_progress STEP 1 || logger -t "$MYTAG" "db_progress STEP before script(s) loop failed."
    for script in $earlyscripts ; do
	logger -t "$MYTAG" "Early script: $script"

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

	logger -t "$MYTAG" "  Launching $script"
	# Passing $MYTAG to scripts
	chmod +x $DLPATH/$script && $DLPATH/$script $MYTAG || exit $?

	db_progress START 0 $STEPS $MYTAG/$MYNAME/progress/title && logger -t "$MYTAG" "  db_progress START (restarting) during earlyscripts."
	db_progress SET 11 || logger -t "$MYTAG" "  db_progress SET during ealyscripts failed."
    done

    db_progress STEP 1 || logger -t "$MYTAG" "Stepping after other scirpts failed."
    db_progress INFO $MYTAG/$MYNAME/progress/scriptsdone || logger -t "$MYTAG" "db_progress INFO scriptsdone failed."
fi

db_progress SET 13 || logger -t "$MYTAG" "db_progress SET before end failed."
db_progress INFO $MYTAG/$MYNAME/progress/end || logger -t "$MYTAG" "db_progress INFO end failed."

db_progress STOP && logger -t "$MYTAG" "db_progress STOP done." || logger -t "$MYTAG" "db_progress STOP failed."
logger -t "$MYTAG" "End of ${MYNAME}.sh"
exit 0
