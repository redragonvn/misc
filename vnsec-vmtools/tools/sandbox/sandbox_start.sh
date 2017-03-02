#!/bin/sh

MOUNT_PROC=1
MOUNT_PORTAGE=0
SANDBOX_BASE=/srv/sandbox
SANDBOX_NAME=$1
shift
CMD=$@

if [ "x$SANDBOX_NAME" = "x" ]; then
	echo "usage: $0 sandbox [command]"
	exit 0
fi

echo Entering sandbox $SANDBOX_NAME

cd $SANDBOX_BASE

if [ $MOUNT_PROC -eq 1 ]; then
	mount --bind /proc $SANDBOX_NAME/proc
fi

if [ $MOUNT_PORTAGE -eq 1 ]; then
	mount --bind /usr/portage $SANDBOX_NAME/usr/portage
fi


chroot $SANDBOX_NAME $CMD

if [ $MOUNT_PROC -eq 1 ]; then
	umount $SANDBOX_NAME/proc
fi

if [ $MOUNT_PORTAGE -eq 1 ]; then
	umount $SANDBOX_NAME/usr/portage
fi


echo Bye!
