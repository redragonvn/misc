#!/bin/sh
# 
# Create new chroot snadbox from Stage3
# --rd

usage()
{
	echo 
        echo "Usage: `basename $0` -i SANDBOXID [options]"
        echo "  -i SANDBOXID         ID of SANDBOXs (0-99)"
        echo "  -a IP           IP Address of SANDBOX (default $IP)"
        echo "  -3 Stage3       Path to Stage3 archive (default $STAGE3BIN)"
        echo "  -h              Print help"

        exit 1
}

parseopts () {
	while getopts ":hi:a:3:" optname
    	do
      		case "$optname" in
        	"i")
          		SANDBOXID=$OPTARG
          		;;
        	"a")
          		IP=$OPTARG
          		;;
        	"3")
          		STAGE3BIN=$OPTARG
          		;;
        	"h")
          		usage
          		;;
        	"?")
          		echo "Unknow option $OPTARG"
			usage
          		;;
        	":")
          		echo "No argument value for option $OPTARG"
			usage
          		;;
        	*)
          		echo "Unknown error while processing options"
			usage
          		;;
      		esac
    	done

	ARG=${@:$OPTIND}
	if [ ! "x$ARG" = "x" ]; then
        	echo "Unknow argument $ARG"
		usage
	fi

	if [ "x$SANDBOXID" = "x" ]; then 
		echo "No SANDBOXID provided"
		usage
	fi
}

# parse opt
parseopts "$@"


# Base DIR
BASEDIR=/srv/SANDBOX
ROOTDIR=$BASEDIR/$SANDBOXID
DISTDIR=$BASEDIR/distfiles
TEMPLATEDIR=$BASEDIR/template

# SANDBOX ID / NAME
SANDBOXNAME=SANDBOX$SANDBOXID

# mount pojnt
TARGET=$ROOTDIR/$SANDBOXNAME

# package info
STAGE3BIN=${STAGE3BIN-$DISTDIR/stage3-amd64-hardened+nomultilib-20091112.tar.bz2}
PORTAGEBIN=${PORTAGEBIN-$DISTDIR/portage-latest.tar.bz2}
 
# SANDBOX config
TEMPLATECONF=$TEMPLATEDIR/gentoo.xen3.cfg.tmpl
SANDBOXCONF=$CONFDIR/$SANDBOXNAME.xen3.cfg
VCPUS=${VCPUS-2}
KERNEL=${KERNEL-$KERNELDIR/kernel-2.6.31-xenU}
SANDBOXMEM=${SANDBOXMEM-1536}
ROOTDEV_SANDBOX=/dev/sda1
SWAPDEV_SANDBOX=/dev/sda2

TIMEZONE=UTC
HOSTNAME=$SANDBOXNAME
VIFNAME=vif$SANDBOXNAME
IP=${IP-88.198.55.221}
NETMASK=255.255.255.224 
BROADCAST=188.198.55.223
GW=88.198.55.199


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
	echo "New SANDBOX infomation:"
	echo -e "==Base:"
	dumpvars SANDBOXID SANDBOXNAME ROOTSIZE SWAPSIZE ROOTDEV SWAPDEV TARGET STAGE3BIN PORTAGEBIN 
	echo -e "==SANDBOX:"
	dumpvars VCPUS KERNEL SANDBOXMEM IP TEMPLATECONF SANDBOXCONF
}

_check()
{
	# if the device exists
	if [ -e $ROOTDEV ] || [ -e $SWAPDEV ]; then
		echo "ERROR: $ROOTDEV or $SWAPDEV exists. Please choose other ID or delete the old disk volume"
		exit 1
	fi

	# check target
	if [ -d $TARGET ]; then
		echo "ERROR: $TARGET exists. Please choose other ID or delete it."
		exit 1
	fi

	if [ -f $SANDBOXCONF ]; then
		echo "ERROR: $SANDBOXCONF exists. Please choose other ID or delete it."
		exit 1
	fi
	
}


create_volume()
{
	# only create if the device doesn't exits
	if [ -e $ROOTDEV ] || [ -e $SWAPDEV ]; then
		echo "ERR $ROOTDEV or $SWAPDEV exists"
		exit 1
	fi

	# create root & swap logical volume
	lvcreate -L$ROOTSIZE -n$ROOTDEV_NAME vg
	lvcreate -L$SWAPSIZE -n$SWAPDEV_NAME vg
	
	# swap
	mkfs.ext3 $ROOTDEV
	mkswap $SWAPDEV
}

stage3_install()
{
	mkdir -p $TARGET

	# mount
	mount $ROOTDEV $TARGET
	tar xjpf $STAGE3BIN -C $TARGET
	tar xjpf $PORTAGEBIN -C $TARGET/usr

	# portage overlay
	mkdir -p $TARGET/usr/local/portage
}

# replace the value from template file with args
# usage template template_file VAR1 VAR2 VAr3 ...
template()
{
	local TFILE=$1
	shift

	for var in $@; do
		eval TMP="s!%$var%!\$$var!\;"
		CMD=$CMD$TMP
	done
	sed -e "$CMD" $TFILE
}

stage3_config()
{
	# make.conf
	cp -L $TEMPLATEDIR/make.conf $TARGET/etc/

	# date/time
	cp -L $TARGET/usr/share/zoneinfo/$TIMEZONE $TARGET/etc/localtime
	echo 'TIMEZONE="$TIMEZONE"' >> $TARGET/etc/conf.d/clock

	# hostname
	echo "127.0.0.1 $SANDBOXNAME localhost" > $TARGET/etc/hosts
	sed -i -e "s/HOSTNAME.*/HOSTNAME="$SANDBOXNAME"/" $TARGET/etc/conf.d/hostname

	# mount
	template $TEMPLATEDIR/fstab.tmpl ROOTDEV_SANDBOX SWAPDEV_SANDBOX > $TARGET/etc/fstab

	# network
	cp -L $TEMPLATEDIR/resolv.conf $TARGET/etc/

	template $TEMPLATEDIR/net.tmpl IP NETMASK BROADCAST GW > $TARGET/etc/conf.d/net
	
	#echo 'config_eth0=( "$IP netmask $NETMASK brd $BROADCAST" )' > $TARGET/etc/conf.d/net
	#echo 'routes_eth0=( "default gw $GW" )' >> $TARGET/etc/conf.d/net
}

domU_config()
{
	template $TEMPLATECONF VCPUS KERNEL SANDBOXMEM SANDBOXNAME IP VIFNAME ROOTDEV ROOTDEV_SANDBOX SWAPDEV SWAPDEV_SANDBOX > $SANDBOXCONF 
}



_dumpinfo
! _confirm "Continue?" && exit 1 

_check

echo "Creating disk volume for $SANDBOXNAME ..."
create_volume
echo -e "Done\n"

echo "Installing Stage3..."
stage3_install
echo -e "Done\n"

echo "Configuring SANDBOX..."
stage3_config
echo -e "Done\n"

echo "Creating $SANDBOXCONF" 
domU_config 
echo -e "Done\n"

umount $TARGET
echo "Run 'xm create $SANDBOXCONF' to start SANDBOX"


