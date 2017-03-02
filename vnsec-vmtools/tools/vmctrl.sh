#!/bin/sh
# 
# manage xen domU vms
# --rd

usage()
{
	echo 
        echo "Usage: `basename $0` VMID [start|stop|info|list|top|console]"
        exit 1
}

if [ $# -ne 2 ]; then
	usage
fi

VMID=$1
CMD=$2

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
	dumpvars VMID VMNAME ROOTDEV SWAPDEV TARGET VMCONF
}

case "$CMD" in
    start)
	xm create $VMCONF -c
        ;;
    stop)
	xm shutdown $VMCONF
        ;;
    info)
	xm info 
	;;
    list)
	xm list
	;;
    top)
	xm top
	;;
    console)
	xm console $VMCONF
	;;
esac



