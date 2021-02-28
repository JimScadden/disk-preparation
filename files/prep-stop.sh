#!/bin/sh
# Copyright (c) 2021, Magnus Sandberg
# BSD 2-Clause "Simplified" License

MYTAG="my-stuff"
MYNAME="prep-stop"
DLPATH="/tmp/my-stuff"
logger -t "$MYTAG" "    ${MYNAME} started."

cat > $DLPATH/$MYNAME.template <<EOT
Template: $MYTAG/$MYNAME/title
Type: title
Description: Disk preparation stop
 Stopping at the last stage before Partman stage.

Template: $MYTAG/$MYNAME/note
Type: note
Description: Last warning...
 This is the last stop before starting Partman.
 .
 If you have to look into any details, stop,
 or change stuff, the time is now.
EOT
logger -t "$MYTAG" "    Template create in $DLPATH/$MYNAME.template"

# Load functions etc
. /usr/share/debconf/confmodule
logger -t "$MYTAG" "    Debconf confmodule functions loaded."

db_version 2.0

# Make sure we don't have the progress bar from parent script shown
db_progress STOP && logger -t "$MYTAG" "    db_progress STOP of parent script progress bar done." || logger -t "$MYTAG" "    db_progress STOP of parent script progress bar failed."

# Load template
debconf-loadtemplate $MYTAG $DLPATH/$MYNAME.template
logger -t "$MYTAG" "    Debconf template loaded."

db_settitle $MYTAG/$MYNAME/title || logger -t "$MYTAG" "    db_settitle failed"
db_input high $MYTAG/$MYNAME/note || logger -t "$MYTAG" "    db_input with note skipped/failed"

logger -t "$MYTAG" "    db_go note will be displayed."
db_go && logger -t "$MYTAG" "    db_go done." || logger -t "    $MYTAG" "db_go failed."

exit 0
