#!/bin/sh 
#
# S.McKenna Big Hog written for HP-UX 08/04/2011
#	cmd -v -p -h -l --
#	-v verbose turns on debugging
#	-d generate detailed report
#	-p preview mode does no mail
#	-l log file other than the standard /var/tmp/BigHogReport.$$
#	-h this information and exits
#	
#     other options, (the main ones), are in order!
#		'mountpoint',
#		'to email, and 
#		'cc email (optional)'
#   
# -------------------------------------------------------------------- #
# S.McKenna 2020/09/02. Modified to retain logfiles and save them in   #
# /home/caxrpt/reportdata/disk_usage_user.$(basename $1).$(date +%F)   #
# logfiles are located in caxrpt home and need to be re-owned.         #
# -------------------------------------------------------------------- #
#
#
rval=0

set_return()
{
    x=$?
    rval=0
    if [ $x -ne 0 ]; then
        echo "EXIT CODE: $x"
        rval=1  # always 1 so that 2 can be used for other reasons
    fi
}

export USAGE="cmd -v -p -h --\n \n -v verbose does nothing\n -d generate detailed reports\n -p preview mode send no email\n -l log file passed in instead of auto generated\n -h help\n 'mountpoint' 'to email' 'cc email' (optional)\n"
export MYNAME=${0##/*}
export PREVIEW=0
export DETAILED=0
export RPTFILE=/home/caxrpt/reportdata/disk_usage_user
export RPTFILE=/var/tmp/CAE_usage_log_user
export RPTFILE=/var/tmp/BigHogReport.$$
export CSVFILE=/var/tmp/BigHogCSV$$
export RPTFILE_PASSED=0
export RPTFILE_PASSED=1


f_usage()
{
echo $USAGE
}
set -- `getopt dvphpo:l: $*`
if [ $? -ne 0 ]; then
        echo $USAGE
        exit 2
fi
#set -xv
while [ $# -gt 0 ]; do
        case $1 in
            -d) DETAILED=1 ; shift ;;
            -v) VERBOSE=1 ; shift ;;
            -p) PREVIEW=1 ; shift ;;
            -l) shift; RPTFILE=$1; RPTFILE_PASSED=1 ; shift ;;
            -h) f_usage; exit ;;
            --) shift     ; break ;;
        esac
done
echo $RPTFILE_PASSED
if [ $RPTFILE_PASSED = 1 ] ;then
	if [ ! -f $RPTFILE ];then
		echo "invalid file name $RPTFILE"
		exit 12
	fi
	echo "Lets append reports to $RPTFILE"	
fi	

########################################################################
# Main body                                                            #
########################################################################

echo "Begin Processing."
if [ ! -d $1 ]; then
	echo "$1 Filesystem does not exist"
        return 1
fi

if [ $VERBOSE = 1 ]; then
	echo "Verbose set: debugging turned on"
	set -xv
fi

# Testing file
#export RPTFILE=/var/tmp/BigHogReport.$(basename $1).$(date +%F)
#export CSVFILE=/var/tmp/BigHogReport.$(basename $1).$(date +%F).new
if [ ! $RPTFILE_PASSED = 1 ] ;then
	export RPTFILE=/home/caxrpt/reportdata/disk_usage_user/CAE_usage_log_user.$(basename $1).$(date +%F)
	export CSVFILE=/home/caxrpt/reportdata/disk_usage_user/CAE_usage_log_user.$(basename $1).$(date +%F).new
fi
#

if [ ! $RPTFILE_PASSED = 1 ] ;then
	[ -f $RPTFILE ] && {
	mv ${RPTFILE} $RPTFILE.pre-$(date +%F:%T)
	touch $RPTFILE
}
fi

echo $RPTFILE
echo $CSVFILE

#[ -d $RPTFILE ] || mkdir -p $RPTFILE
[ -f $RPTFILE ] 
if [ ! $RPTFILE_PASSED = 1 ] ;then
    df -kP $1 > $RPTFILE
else
    df -kP $1 >> $RPTFILE
fi

#LH=$(date +%F)","$(df -k --output=size,used,avail,pcent,source  $1 | tail -n 1 | sed -e 's/  / /g' | sed -e 's/ /,/g')
LH=$(date +%F)","$(df -k --output=size,used,avail,pcent $1 | tail -n 1 | sed -e 's/  / /g' | sed -e 's/ /,/g')
echo "" >> $RPTFILE
echo "20 Largest Directories within $1" >> $RPTFILE
echo "" >> $RPTFILE
#echo " MB Used      Directory Name" >> $RPTFILE
echo " GB Used      Directory Name" >> $RPTFILE
#--------------------------------------------------------------------------------------------------------------#
du -sxk /$1/* 2> /dev/null | sort -rn | grep -v 'lost+found' | head -n 20 | while read a b;do
if [[ ! -h $b ]];then
    x=$(echo $a | sed -e 's/\/$//') 
    echo $x " "  $b |  awk '{printf("%12.2f      %s\n", ($1)/1024/1024, $2)}' >>$RPTFILE
#    LD=$(echo $x " "  $b |  awk '{printf("%12.2f     ,%s\n", ($1)/1024/1024, $2)}')
    LD2=$( echo $b | awk -F/ '{print $NF}')
    LD=$(echo $x " "  $b |  awk -v c=$LD2 '{printf("%12.2f     ,%s\n", ($1)/1024/1024, c)}')

# test line
    echo $LH","$(basename $CSVFILE)",$(uname -n | cut -c 1-3 |  tr "[:lower:]" "[:upper:]")CAX Server,"$(echo $1 | sed -e 's!/!!')",CAE,"$LD >> $CSVFILE
fi
done

## notes on above. S.McKenna
#--------------------------------------------------------------------------------------------------------------#
echo "" >> $RPTFILE
if [ $DETAILED = 1 ]; then
    echo "20 Largest Files within $1 Created or Modified in last 24 Hours" >> $RPTFILE
    echo "" >> $RPTFILE
    find $1 -xdev -type f -mtime -1 -exec ls -l {} \; | sort -k 5rn | head -20 | sed 's/^ *[0-9]* *[0-9]*//' >> $RPTFILE
fi
echo "" >> $RPTFILE
#
if [ $DETAILED = 1 ]; then
    echo "20 Largest Files within $1" >> $RPTFILE
    echo "" >> $RPTFILE
    find $1 -xdev -type f -exec ls -l {} \; | sort -k 5rn | head -20 | sed 's/^ *[0-9]* *[0-9]*//' >> $RPTFILE
    echo "" >> $RPTFILE
fi
#echo "TSM*Keyword" >> $RPTFILE
exit

if [ $PREVIEW = 1 ]; then
	echo "Preview set: no mail will be sent"
else
	echo "Preview not set: mail will be sent"
	if [ -z "$3" ]; then
	        mailx -s "$(uname -n) Capacity Usage report for $1 " "$2" <$RPTFILE
	else
	        mailx -s "$(uname -n) Capacity Usage report for $1 " "$3"",""$2" <$RPTFILE
#	        mailx -s "Capacity Usage report for $1 on $(uname -n)" "$3"",""$2" <$RPTFILE
	fi
	echo "Capacity Usage report for $1 sent to: $2 cc: $3"
fi
#[ -f $RPTFILE ] && rm $RPTFILE

# -------------------------------------------------------------------- #
# logfiles are located in caxrpt home and need to be re-owned.         #
# /home/caxrpt/reportdata/disk_usage_user.$(basename $1).$(date +%F)   #
# -------------------------------------------------------------------- #
#
chown caxrpt:caxrpt $RPTFILE

if [[ $RPTFILE_PASSED = 0 ]];then
    rm $RPTFILE
fi


echo "End Processing."
return 0
