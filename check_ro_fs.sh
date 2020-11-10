#!/bin/sh 
# --------------------------------------------------------------------------- #
# This script checks a list of (presumably NFS) mount points                  #
# and checks if they are in 'read only' state.                                #
# If it find a 'read only' mount point, it attempts to                        #
# remount it 'read write' to avoid any disruption for processes               #
# accessing the mount point.                                                  #
# Some kind of email report will be generated.                                #
# S.McKenna 04/01/2020. Created script (no joke)                              #
#                                                                             #
# --------------------------------------------------------------------------- #
logfile="/var/tmp/check_ro_fs.log.$$"
cat /dev/null >  $logfile
touch $logfile

for i in ds001 ds002 ds003 ds004;do
    echo "" >> $logfile
    echo "Checking mount point:/"$i >> $logfile
    echo "" >> $logfile
    [[ $(grep "[[:space:]]ro[[:space:],]" /proc/mounts | grep $i) ]] && {
       echo $i mounted read only >> $logfile 2>&1
       echo remounting $i >> $logfile 2>&1
       mount -o remount,rw,bind /$i >> $logfile 2>&1
       df -h /$i >> $logfile 2>&1
       [[ $(grep "[[:space:]]ro[[:space:],]" /proc/mounts | grep $i) ]] && {
	echo remount read write $i did not work >> $logfile 2>&1
	}
    }
done
mailx -s "$(uname -n) check for read only mount points report" root < $logfile
exit

