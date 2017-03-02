#!/bin/sh

SANDBOX=/srv/sandbox
BASEDIR=base
DESTDIR=$1

if [ "x$DESTDIR" = "x" ]; then
	echo "usage: $0 targetname"
	exit 0
fi

cd $SANDBOX/$BASEDIR
find . -depth -print | cpio -pvd $SANDBOX/$DESTDIR
cd -


