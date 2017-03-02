#!/bin/sh

cd /srv/sandbox/

# force shell
echo "restarting force"
/bin/umount shells/proc/
/bin/mount -t proc none shells/proc/
/usr/bin/chroot shells/ /etc/init.d/sshd stop
/usr/bin/chroot shells/ /etc/init.d/sshd start

# start vnsec
echo "restarting plone-vnsec"
/usr/bin/chroot plone-vnsec/ /opt/Plone-2.5.2/zeocluster/bin/shutdowncluster.sh 
/usr/bin/chroot plone-vnsec/ /opt/Plone-2.5.2/zeocluster/bin/startcluster.sh 

# start plone hosting
echo "restarting plone-hosting"
/usr/bin/chroot plone-hosting/ /opt/Plone-2.5.2/zeocluster/bin/shutdowncluster.sh 
/usr/bin/chroot plone-hosting/ /opt/Plone-2.5.2/zeocluster/bin/startcluster.sh 

# httpd
echo "restarting httpd"
/usr/bin/chroot lighttpd/ /etc/init.d/lighttpd stop
/bin/rm -f lighttpd/var/lib/init.d/started/lighttpd
/usr/bin/chroot lighttpd/ /etc/init.d/lighttpd start
