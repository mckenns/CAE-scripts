#!/bin/sh 
#--------------------------------------------------------------------------------#
# Script to manage 'Big Hog' reports for HP-UX systems
# S. McKenna 01/01/2011
#--------------------------------------------------------------------------------#
Me=`basename ${0}`
#LOGDIR=/usr/eds/local/rpt
LOGDIR=/caehome/mckenns/tmp
LOG_NAME=$Me.log_`date +'%Y%m%d:%H%M'`
echo $LOG_NAME
#exec >>${LOGDIR}/${LOG_NAME} 2>&1
typeset -i LIMIT pct
LIMIT=1
echo $LIMIT
BIGHOG='/usr/local/bin/BigHogReport.sh'
BIGHOGCONF='/usr/local/SAetc/BigHog.conf'
BIGHOG='/home/mckenns/BigHogReport_v3.2.sh'
BIGHOGCONF='/home/mckenns/BigHog.conf'
export to cc
#
#
function filter {
awk '
BEGIN{
DISTRIBUTION[1]=":90:sio-cae@aam.com:cae-unix@aam.com"
DISTRIBUTION[2]=":0:BigHogESI:BigHogEDS"
DIRECTORY["/auditlog1"]=2
DIRECTORY["/tmp"]=2
DIRECTORY["/tsmdb"]=2
DIRECTORY["/tsmdbv1"]=2
DIRECTORY["/tsmsp3"]=2
}
NR>1{
if ( $1 in DIRECTORY )
print $1 DISTRIBUTION[DIRECTORY[$3]]
else
print $1 DISTRIBUTION[1]
next
}'
}
export USAGE="cmd -v -p -h --\n \n -v verbose does nothing\n -d generate detailed reports\n -p preview mode send no email\n -l log file passed in instead of auto generated\n -h help\n 'mountpoint' 'to email' 'cc email' (optional)\n"
export MYNAME=${0##/*}
export PREVIEW=0
export let DETAILED=false;SUMMARY=false
#export RPTFILE=/home/caxrpt/reportdata/disk_usage_user
export RPTFILE=/var/tmp/CAE_usage_log_user
export RPTFILE=/var/tmp/BigHogReport.$$
export CSVFILE=/var/tmp/BigHogCSV$$
export RPTFILE_PASSED=0
#export RPTFILE_PASSED=1

echo "Detailed:"$DETAILED
echo "Summary:"$SUMMARY

f_usage()
{
echo $USAGE
echo ="cmd -v -d -p -l {file name} -s -c {file name}
	--
	
	-v verbose does nothing

	-d generate detailed reports (default)

	-p preview mode send no email

	-l log file passed in instead of auto generated
	   file will be created if it does not exist

	-s generate summary reports. all listed filesystems will be reported one time
	   to a random user selected from the configuration file.  :)

	-c name of CSV file to be used with summary option for all filesystem.
           Otherwise, /home/caxrpt/reportdata folders will be used	   

	-h help
	
	'mountpoint' 'to email' 'cc email' (optional)
	"
}
set -- `getopt dsvphpo:l:c: $*`
if [ $? -ne 0 ]; then
        echo $USAGE
        exit 2
fi
#set -xv
while [ $# -gt 0 ]; do
        case $1 in
            -d) DETAILED=true ; shift ;;
            -s) SUMMARY=true ; shift ;;
            -v) VERBOSE=1 ; shift ;;
            -p) PREVIEW=1 ; shift ;;
            -l) shift; RPTFILE=$1; RPTFILE_PASSED=1 ; shift ;;
            -c) shift; CSVFILE=$1; CSVFILE_PASSED=1 ; shift ;;
            -h) f_usage; exit ;;
            --) shift     ; break ;;
        esac
done
if [ $SUMMARY  ] ;then
    if [ $RPTFILE_PASSED = 1 ] ;then
	echo $RPTFILE_PASSED
        if [ ! -f $RPTFILE ];then
                echo "invalid file name $RPTFILE"
                touch $RPTFILE
#		exit 12
        fi
        echo "Lets append reports to $RPTFILE"
    fi
else
        echo "Lets append reports to $RPTFILE"
fi

if [ $SUMMARY  ] ;then
    if [ $CSVFILE_PASSED = 1 ] ;then
	echo $CSVFILE_PASSED
        if [ ! -f $CSVFILE ];then
                echo "invalid file name $CSVFILE"
                touch $CSVFILE
#		exit 12
        fi
        echo "Lets append csv rows  to $CSVFILE"
    fi
else
        echo "Lets append csv data to $CSVFILE"
fi

########################################################################
# Main body                                                            #
########################################################################

echo "Detailed:"$DETAILED
echo "Summary:"$SUMMARY
#--------------------------------------------------------------------------------#
# Get a list of the locally mounted filesystems, excluding                       #
#  '/dev/deviceFileSystem'                                                       #
#--------------------------------------------------------------------------------#
#	
case $(uname) in
	"HP-UX")
	DF1="df -nl "
	DF2="df -v "
	;;
	"Linux")
	DF1="df -l --output=target,source,fstype" 
	# only the first and last fileds are used. the rest are filler so I can work his
	# for HP-UX and Linux. S.McKenna
	DF2="df -v --output=target,source,file,size,pcent"
	;;
	*)
	echo "${OS-NAME} is not supported"
	exit 99
	;;
esac

    #$DF1 | grep -v -e '^\/dev' -e '^Mounted' -e '^\/sys' -e '^\/run' | awk '{print $1}' | while read mnt;do

    #--------------------------------------------------------------------------------#
    # Check to see if any of them are over the threshold, either a default value of  #
    # 'LIMIT' or an entry in file BIGHOGCONF or in the 'filter' list above           #
    #--------------------------------------------------------------------------------#
    if [ -e $BIGHOGCONF ];then
	for mnt in $( cat $BIGHOGCONF | grep -v '^#' | awk -F: '{print $1}');do

	    $DF2 $mnt | grep -v 'Mounted on' | awk '{print $5}' | sed -e 's/%//' | while read pct therest;do
	    limit=$LIMIT
	    if [ `grep "^""$mnt"":" ${BIGHOGCONF}` ];then
	        x=`grep "^""$mnt"":" $BIGHOGCONF | awk -F: '{print $2}'` > /dev/null
		to=`grep "^""$mnt"":" $BIGHOGCONF | awk -F: '{print $3}'` > /dev/null
		cc=`grep "^""$mnt"":" $BIGHOGCONF | awk -F: '{print $4}'` > /dev/null
		limit=$x
		if [ ${pct} -le ${limit} ];then
			continue
		else
	echo "To:"$to
	echo "cc:"$cc
#	 	    filter $mnt
	echo "To:"$to
	echo "cc:"$cc
		    echo $mnt ":"$pct
#		    nohup /usr/bin/sudo $BIGHOG $mnt $to $cc -l $RPTFILE 
		    if [ $DETAILED = 1 ]; then
		        nohup /usr/bin/sudo $BIGHOG $mnt 
		    else
		    	if [ $CSVFILE_PASSED = 1 ]; then
		        	nohup /usr/bin/sudo $BIGHOG $mnt  -l $RPTFILE -c $CSVFILE
		        else
		        	nohup /usr/bin/sudo $BIGHOG $mnt  -l $RPTFILE 
		    	fi	# IF DETAILED
		    fi	# IF DETAILED
		fi	# ${pct} -le ${limit}
	    else
		limit=$LIMIT
	    fi # if [ `grep "^""$mnt"":" ${BIGHOGCONF}` ];then
#

##
	    done #$DF2 | grep $mnt | awk '{print $5}' | sed -e 's/%//' | while read pct therest;do

	done # for $mnt in $( cat $BIGHOGCONF | grep -v '^#' | awk -F: '{print $1}');do

    else

        echo "Configuration file "${BIGHOGCONF}" not found"
        exit 24

    fi # if [ -e $BIGHOGCONF ];then
	#--------------------------------------------------------------------------------#
	# df -v $mnt | grep $mnt | awk -F : '{print $2}' | sed -e 's/%//' | ....         #
	#--------------------------------------------------------------------------------#
if [ $DETAILED = 1 ]; then
	exit 
fi
if [ $PREVIEW = 1 ]; then
        echo "Preview set: no mail will be sent"
else
	if [ `grep "^""$mnt"":" ${BIGHOGCONF}` ];then
		x=`grep "^""$mnt"":" $BIGHOGCONF | awk -F: '{print $2}'` > /dev/null
	        to=`grep "^""$mnt"":" $BIGHOGCONF | awk -F: '{print $3}'` > /dev/null
	        cc=`grep "^""$mnt"":" $BIGHOGCONF | awk -F: '{print $4}'` > /dev/null
	fi

        echo "Preview not set: mail will be sent"
	echo "To:"$to
	echo "cc:"$cc

        if [ -z "$cc" ]; then
                mailx -s "$(uname -n) Capacity Usage report for $(date +%F)" "${to}" <$RPTFILE
        else
                mailx -s "$(uname -n) Capacity Usage report for $(date +%F)" "${cc}"",""${to}" <$RPTFILE
        fi
        echo "Capacity Usage report for $1 sent to: $2 cc: $3"
fi

#done #$DF1 | grep -v -e '^\/dev' -e '^Mounted' -e '^\/sys' -e '^\/run' | awk '{print $1}' | while read mnt;do
#--------------------------------------------------------------------------------#
# df -nl | grep -v  -e '\/dev\/deviceFileSystem' -e '^Mounted' | ....            #
#--------------------------------------------------------------------------------#
exit
