#!/bin/sh

SANDBOX=/srv/sandbox
BASEDIR=$1
DESTDIR=$2

if [ ! -d $BASEDIR ]; then
	echo $BASEDIR is not a directory
	exit 0
fi


if [ "x$DESTDIR" = "x" ]; then
	echo "usage: $0 targetname"
	exit 0
fi

cd $SANDBOX/$BASEDIR
find . -depth -print | cpio -pvd $SANDBOX/$DESTDIR
cd -


