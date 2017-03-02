#!/bin/sh
#
# setup private networking for VM
# --rd

VMCONFIGDIR=/srv/VM/config

command=$1
vif_ip=$2
vifname=$3
dom0_ip=$4

VMNAME=${vifname#vif}

getdomU_ip()
{
	echo `/bin/grep ",$VMNAME," $VMCONFIGDIR/VMINFO | /usr/bin/cut -f1 -d","`
}

getdomu_port_forward()
{
	echo `/bin/grep ",$VMNAME," $VMCONFIGDIR/VMINFO | /usr/bin/cut -f6 -d","`
}

domU_ip=$(getdomU_ip)
ports=$(getdomu_port_forward)

#echo $domU_ip
#echo $ports

case "$command" in
    online)
	# setup NAT
	/sbin/iptables --table nat -A POSTROUTING -o eth0 -s $domU_ip -j MASQUERADE

	# setup port forwarding
	for port in ${ports} ; do
		extport=${port%:*}
		intport=${port#*:}
		/sbin/iptables -t nat -A PREROUTING -p tcp -i eth0 -d $dom0_ip --dport $extport -j DNAT --to $domU_ip:$intport
        done
	;;
    offline)
	# remove NAT
	/sbin/iptables --table nat -D POSTROUTING -o eth0 -s $domU_ip -j MASQUERADE
	
	# remove port forwarding
	for port in ${ports} ; do
                extport=${port%:*}
                intport=${port#*:}
                /sbin/iptables -t nat -D PREROUTING -p tcp -i eth0 -d $dom0_ip --dport $extport -j DNAT --to $domU_ip:$intport
        done
        ;;
esac

