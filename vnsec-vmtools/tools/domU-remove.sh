#!/bin/sh
# 
# create a new gentoo domU
# --rd

usage()
{
	echo 
        echo "Usage: `basename $0` VMID"
        exit 1
}

if [ $# -ne 1 ]; then
	usage
fi

VMID=$1

# Base DIR
BASEDIR=/srv/VM
ROOTDIR=$BASEDIR/ROOT
CONFDIR=$BASEDIR/config

# VM ID / NAME
VMNAME=VM$VMID
VMCONF=$CONFDIR/$VMNAME.xen3.cfg

# mount pojnt
TARGET=$ROOTDIR/$VMNAME

ROOTDEV_NAME=$VMNAME
SWAPDEV_NAME=$VMNAME-SWAP
ROOTDEV=/dev/vg/$ROOTDEV_NAME
SWAPDEV=/dev/vg/$SWAPDEV_NAME


dumpvars()
{
	for var in $@; do
		eval echo -e "\\\t$var: \$$var"
	done
}


_confirm()
{
echo -n "$1 ? (n) "
read ans
[ "x$ans" == "xy" ] && return 0 || return 1
}

_dumpinfo()
{
	# display info
	echo "Delete VM:"
	dumpvars VMID VMNAME ROOTDEV SWAPDEV TARGET VMCONF
}

delete_volume()
{
	umount $TARGET
	# delete logical volume
	lvremove $ROOTDEV
	lvremove $SWAPDEV
	rm -ir $TARGET
}

_dumpinfo
! _confirm "Continue?" && exit 1 


echo "Deleting disk volume for $VMNAME ..."
delete_volume
echo -e "Done\n"

echo "Delete $VMCONF" 
rm -i $VMCONF
echo -e "Done\n"

