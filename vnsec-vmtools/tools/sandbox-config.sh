#!/bin/sh
# 
# sandbox config
# --rd

usage()
{
	echo 
        echo "Usage: `basename $0` -d TARGET [options]"
        echo "  -d TARGET      Destination"
        echo "  -a IP           IP Address of VM (default $IP)"
	echo "  -n HOSTNAME	Hostname"
        echo "  -h              Print help"

        exit 1
}

parseopts () {
	while getopts ":hd:a:n:" optname
    	do
      		case "$optname" in
        	"d")
          		TARGET=$OPTARG
          		;;
        	"a")
          		IP=$OPTARG
          		;;
		"n")
			HOSTNAME=$OPTARG
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

	if [ "x$TARGET" = "x" ]; then 
		echo "No TARGET provided"
		usage
	fi
}

# parse opt
parseopts "$@"

# Base DIR
BASEDIR=/srv/VM
ROOTDIR=$BASEDIR/ROOT
CONFDIR=$BASEDIR/config
DISTDIR=$BASEDIR/distfiles
TEMPLATEDIR=$BASEDIR/template

# VM config
TIMEZONE=UTC
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
	echo "New Configuration:"
	dumpvars HOSTNAME TARGET IP TEMPLATEDIR TIMEZONE
}

_check()
{
	# check target
	if [ ! -d $TARGET ]; then
		echo "ERROR: $TARGET doesn't exists." 
		exit 1
	fi
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

_config()
{
	# make.conf
	cp -i -L $TEMPLATEDIR/make.conf $TARGET/etc/

	# sshd
	cp -i -L $TEMPLATEDIR/sshd_config $TARGET/etc/ssh/

	# date/time
	cp -i -L $TARGET/usr/share/zoneinfo/$TIMEZONE $TARGET/etc/localtime
	echo "TIMEZONE=\"$TIMEZONE\"" >> $TARGET/etc/conf.d/clock

	# hostname
	echo "127.0.0.1 $HOSTNAME localhost" > $TARGET/etc/hosts
	sed -i -e "s/HOSTNAME.*/HOSTNAME="$HOSTNAME"/" $TARGET/etc/conf.d/hostname

	# mount
	#template $TEMPLATEDIR/fstab.tmpl ROOTDEV_VM SWAPDEV_VM > $TARGET/etc/fstab

	# network
 	cp -i -L $TEMPLATEDIR/resolv.conf $TARGET/etc/

	template $TEMPLATEDIR/net.tmpl IP NETMASK BROADCAST GW > $TARGET/etc/conf.d/net
	
	# set root password
	#echo "Please set root password"
	#chroot $TARGET /usr/bin/passwd 
}

_dumpinfo
! _confirm "Continue?" && exit 1 

_check

echo "Configuring VM..."
_config
echo -e "Done\n"
