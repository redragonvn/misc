#!/bin/sh
# 
# create a new gentoo domU (vnsec only)
# --rd

usage()
{
	echo 
        echo "Usage: `basename $0` -i VMID [options]"
        echo "  -i VMID         ID of VMs (0-99)"
        echo "  -r ROOTSIZE     Size of ROOT (default $ROOTSIZE)"
        echo "  -s SWAPSIZE     Size of SWAP (default $SWAPSIZE)"
	echo "  -v SRVSIZE	Size of SRV (default $SRVSIZE)"
        echo "  -p VCPUS        Number of VCPU (default $VCPUS)"
        echo "  -k Kernel       Path to domU kernel (default $KERNEL)"
        echo "  -m VMMEM        VM memory size in MB  (default $VMMEM)"
        echo "  -a IP           IP Address of VM (default $IP)"
        echo "  -3 Stage3       Path to Stage3 archive (default $STAGE3BIN)"
	echo "  -0 Image	Path to full image archive (default $IMAGEBIN)"
	echo "  -t Template	Path to template directory"
	echo "  -n Hostname	Hostname"
        echo "  -h              Print help"

        exit 1
}

parseopts () {
	while getopts ":hi:r:s:p:k:m:a:3:0:t:n:v:" optname
    	do
      		case "$optname" in
        	"i")
          		VMID=$OPTARG
          		;;
        	"r")
          		ROOTSIZE=$OPTARG
          		;;
        	"s")
          		SWAPSIZE=$OPTARG
          		;;
        	"v")
          		SRVSIZE=$OPTARG
          		;;
        	"p")
          		VCPUS=$OPTARG
          		;;
        	"k")
          		KERNEL=$OPTARG
          		;;
        	"m")
          		VMMEM=$OPTARG
          		;;
        	"a")
          		IP=$OPTARG
          		;;
        	"3")
          		STAGE3BIN=$OPTARG
          		;;
               "0")
                        IMAGEBIN=$OPTARG
			USEIMAGE=1
                        ;;
               "t")
                        TEMPLATEDIR=$OPTARG
                        USEIMAGE=1
                        ;;
               "n")
                        VMHOSTNAME=$OPTARG
                        USEIMAGE=1
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

	if [ "x$VMID" = "x" ]; then 
		echo "No VMID provided"
		usage
	fi
}

USEIMAGE=0

# parse opt
parseopts "$@"


# Base DIR
BASEDIR=/srv/VM
ROOTDIR=$BASEDIR/ROOT
CONFDIR=$BASEDIR/config
DISTDIR=$BASEDIR/distfiles
TEMPLATEDIR=${TEMPLATEDIR-$BASEDIR/template}
KERNELDIR=$BASEDIR/kernel

# VM ID / NAME
#VMID=99
VMNAME=VM$VMID
VMHOSTNAME=${VMHOSTNAME-$VMNAME}

# Size
ROOTSIZE=${ROOTSIZE-20G}
SWAPSIZE=${SWAPSIZE-3G}
SRVSIZE=${SRVSIZE-30G}

# domU dev
ROOTDEV_NAME=$VMNAME
SWAPDEV_NAME=$VMNAME-SWAP
SRVDEV_NAME=$VMNAME-SRV
SHAREDEV_NAME=VMSHARED
ROOTDEV=/dev/vg/$ROOTDEV_NAME
SWAPDEV=/dev/vg/$SWAPDEV_NAME
SHAREDEV=/dev/vg/$SHAREDEV_NAME
SRVDEV=/dev/vg/$SRVDEV_NAME

# mount pojnt
TARGET=$ROOTDIR/$VMNAME

# package info
STAGE3BIN=${STAGE3BIN-$DISTDIR/stage3-i686-hardened-20091117.tar.bz2}
PORTAGEBIN=${PORTAGEBIN-$DISTDIR/portage-latest.tar.bz2}
IMAGEBIN=${IMAGEBIN-$DISTDIR/gentoo-amd64-hardened-LAMP-20091126.tar.bz2}
 
# VM config
TEMPLATECONF=$TEMPLATEDIR/gentoo.xen3.cfg.tmpl
VMCONF=$CONFDIR/$VMNAME-$VMHOSTNAME.xen3.cfg
VCPUS=${VCPUS-2}
KERNEL=${KERNEL-$KERNELDIR/kernel-2.6.31-xenU}
VMMEM=${VMMEM-1536}
ROOTDEV_VM=/dev/sda1
SWAPDEV_VM=/dev/sda2
SHAREDEV_VM=/dev/sda3
SRVDEV_VM=/dev/sda4
TIMEZONE=UTC
HOSTNAME=$VMHOSTNAME
VIFNAME=vif$VMNAME
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
	echo "New VM infomation:"
	echo -e "==Base:"
	dumpvars VMID VMNAME ROOTSIZE SWAPSIZE SRVSIZE ROOTDEV SWAPDEV SRVDEV TARGET STAGE3BIN PORTAGEBIN IMAGEBIN USEIMAGE
	echo -e "==VM:"
	dumpvars VMHOSTNAME VCPUS KERNEL VMMEM IP TEMPLATECONF VMCONF
}

_check()
{
	# if the device exists
	if [ -e $ROOTDEV ] || [ -e $SWAPDEV ] || [ -e $SRVDEV ]; then
		echo "ERROR: $ROOTDEV or $SWAPDEV or $SRVDEV exists. Please choose other ID or delete the old disk volume"
		exit 1
	fi

	# check target
	if [ -d $TARGET ]; then
		echo "ERROR: $TARGET exists. Please choose other ID or delete it."
		exit 1
	fi

	if [ -f $VMCONF ]; then
		echo "ERROR: $VMCONF exists. Please choose other ID or delete it."
		exit 1
	fi
	
}


create_volume()
{
	# only create if the device doesn't exits
	if [ -e $ROOTDEV ] || [ -e $SWAPDEV ] || [ -e $SRVDEV ]; then
		echo "ERR $ROOTDEV or $SWAPDEV or $SRVDEV exists"
		exit 1
	fi

	# create root & swap logical volume
	lvcreate -L$ROOTSIZE -n$ROOTDEV_NAME vg
	lvcreate -L$SWAPSIZE -n$SWAPDEV_NAME vg
	lvcreate -L$SRVSIZE -n$SRVDEV_NAME vg
	
	# swap
	mkfs.ext3 $ROOTDEV
	mkfs.ext3 $SRVDEV
	mkswap $SWAPDEV
}

image_install()
{
	mkdir -p $TARGET
	# mount
        mount $ROOTDEV $TARGET
	tar xjpf $IMAGEBIN -C $TARGET

	# portage overlay
        mkdir -p $TARGET/usr/local/portage
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

	# ssh
	cp -L $TEMPLATEDIR/sshd_config $TARGET/etc/ssh/
	rm $TARGET/etc/ssh/ssh_host_*

	# date/time
	cp -L $TARGET/usr/share/zoneinfo/$TIMEZONE $TARGET/etc/localtime
	echo "TIMEZONE=\"$TIMEZONE\"" >> $TARGET/etc/conf.d/clock

	# hostname
	echo "127.0.0.1 $VMHOSTNAME localhost" > $TARGET/etc/hosts
	sed -i -e "s/HOSTNAME.*/HOSTNAME="$VMHOSTNAME"/" $TARGET/etc/conf.d/hostname

	# mount
	template $TEMPLATEDIR/fstab.tmpl ROOTDEV_VM SWAPDEV_VM SRVDEV_VM SHAREDEV_VM > $TARGET/etc/fstab

	# network
	cp -L $TEMPLATEDIR/resolv.conf $TARGET/etc/

	template $TEMPLATEDIR/net.tmpl IP NETMASK BROADCAST GW > $TARGET/etc/conf.d/net
	
	#echo 'config_eth0=( "$IP netmask $NETMASK brd $BROADCAST" )' > $TARGET/etc/conf.d/net
	#echo 'routes_eth0=( "default gw $GW" )' >> $TARGET/etc/conf.d/net

	# set root password
	echo "Please set root password"
	chroot $TARGET /usr/bin/passwd 

}

domU_config()
{
	template $TEMPLATECONF VCPUS KERNEL VMMEM VMNAME IP VIFNAME ROOTDEV ROOTDEV_VM SWAPDEV SWAPDEV_VM SRVDEV SRVDEV_VM SHAREDEV SHAREDEV_VM> $VMCONF 
}



_dumpinfo
! _confirm "Continue?" && exit 1 

_check

echo "Creating disk volume for $VMNAME ..."
create_volume
echo -e "Done\n"

if [ $USEIMAGE -eq 0 ]; then
	echo "Installing Stage3..."
	stage3_install
else
	echo "Copying Image..."
	image_install
fi
echo -e "Done\n"

echo "Configuring VM..."
stage3_config
echo -e "Done\n"

echo "Creating $VMCONF" 
domU_config 
echo -e "Done\n"

umount $TARGET
echo "Run 'xm create $VMCONF' to start VM"


