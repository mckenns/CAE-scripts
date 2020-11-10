#!/bin/sh 
#
# qabaq -i JOB 
# ------------------------------------------------------------------- #
# Job to submit starccm+ via LSF to whqlx34,or whqlx35 64-core nodes. #
# ------------------------------------------------------------------- #
# Version 4.2 S. McKenna 2018/08/01.                                  #
# This version includes a license check routine to have the job wait  #
# until a license becomes available.                                  #
# Also, some tidying up of obsolete rocux7 stuff.                     #
# ------------------------------------------------------------------- #
# 4.2.2 for version 12.04.10-R8 (double precision)                    #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# Added TMPDIR, so we can use automount for LSF job submission        #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# Version 4.2 S. McKenna 2020/01/17                                   #
# add user email notification like Web page                           #
# ------------------------------------------------------------------- #

HOST=`uname -n`
SDIR="/scratch/home/$LOGNAME"
JOBLOGDIR=/scratch/joblogs/starccm+
GLOBAL_MODEL=""
JOB_OPTIONS=""
PARALLEL=""
SERVER=whqlx34
SERVER=$(uname -n)
QUEUE=q64
HOST="whqlx34"
HOST=""
CPUS=64
#KMEMORYLIMIT=16777216
KMEMORYLIMIT=31457280
#
VERBOSE="N"
VERBOSE="Y"
[[ -z $TMPDIR ]] && {
    TMPDIR=/tmp
}

export FROM_HOST=$(uname -n)
if [ ${VERBOSE} = "Y" ]; then
    echo "Host name:" ${FROM_HOST}
fi
#
if [ -z ${HEAD_NODE} ]; then
    echo "Head Node not found"
    SERVER="whqlx02"
else
    SERVER=${HEAD_NODE}
fi
#
if [ ${VERBOSE} = "Y" ]; then
    echo "SERVER:" $SERVER
fi

f_check_for_error () {
cat >> $SCRIPT << EOC

if [ \$? -ne 0 ] ; then
echo "Error copying input file to execution host"
exit 24
ERROR=1
fi
EOC
}

f_write_script () {
echo "#!/usr/bin/ksh" > $SCRIPT
cat >> $SCRIPT << EOC
#ulimit -m $KMEMORYLIMIT
MAIL=/usr/bin/mailx
RC=0
export CDLMD_LICENSE_FILE=1999@whqlx34

#cd /scratch$SCRDIR
if [ ! -d "${SDIR}" ];then
    mkdir ${SDIR} || {
    echo "Error creating directory:"  ${SDIR}
   ERROR=1
}
fi

cd ${SDIR} || {
   echo "Error switching to directory:"  ${SDIR}
   ERROR=1
}

mkdir ${INPUT_FILE}.$$ || {
   echo "Error creating directory:"  ${SDIR}"/"${INPUT_FILE}.$$
   ERROR=1
}

cd ${INPUT_FILE}.$$ || {
   echo "Error switching to directory:"  ${SDIR}"/"${INPUT_FILE}.$$
   ERROR=1
}
# ----------------------------------------------------------- #
# Append to log file.                                         #
# ----------------------------------------------------------- #
echo "Starting exec to logfile" >> ${LOGFILE}

exec 1>>${SDIR}"/"${INPUT_FILE}.$$"/"${LOGFILE}
exec 2>>${SDIR}"/"${INPUT_FILE}.$$"/"${LOGFILE}
EOC
# copy input file to execution host scratch home 
if [[ "${INPUT:0:1}" == "/" ]];then
    echo "scp ${FROM_HOST}:$INPUT ." >> $SCRIPT
else
    echo "scp ${FROM_HOST}:$CURDIR/$INPUT ." >> $SCRIPT
fi

f_check_for_error

cat >> $SCRIPT << EOC
# ------------------------------------------------------------------- #
# Hopefully, this is just a convoluted way to saying
# I want to delete my input file at the end of the job, and 
# not I want to delete everything....
# ------------------------------------------------------------------- #

ls > delete.lst
echo launching starccm+ job...
START_TIME="Start time: \`date\`"
echo START_TIME=\$START_TIME
#echo \$START_TIME >> $JOBLOGDIR/$INPUT.$$.log
SUBMIT_SIZE="Before execution directory size: \`du -hs $INPUT\`"
echo SUBMIT_SIZE=\$SUBMIT_SIZE
#echo \$SUBMIT_SIZE >> $JOBLOGDIR/$INPUT.$$.log
if [ ${VERBOSE} = "Y" ]; then
    echo "STARCCM Version:" ${STARCCM_VER}
fi

# ------------------------------------------------------------------- #
# Tested again on 2018/08/01. S.McKenna                               #
# ------------------------------------------------------------------- #
echo "Check for STARCCM+ licenses - this will run forever"
/usr/local/bin/check-ccmppower-licenses.sh

echo "STARCCM+ license available"

EOC
case ${STARCCM_VER} in

"12.04.010")

echo "/opt/CD-adapco/${STARCCM_VER}/STAR-CCM+${STARCCM_VER}/star/bin/starccm+ -power -batch -batchsystem lsf $INPUT 2>&1 || {
echo "STARCCM+ job failed"
exit 99
}" >> $SCRIPT
;;

"12.04.010-R8")

echo "/opt/CD-adapco/${STARCCM_VER}/STAR-CCM+${STARCCM_VER}/star/bin/starccm+ -power -batch -batchsystem lsf $INPUT 2>&1 || {
echo "STARCCM+ job failed"
exit 99
}" >> $SCRIPT
;;

"14.04.013-R8")

echo "/opt/CD-adapco/${STARCCM_VER}/STAR-CCM+${STARCCM_VER}/star/bin/starccm+ -power -batch -batchsystem lsf $INPUT 2>&1 || {
echo "STARCCM+ job failed"
exit 99
}" >> $SCRIPT
;;

*)
echo "Unsupported StartCCM+ version" 
exit 99
;;

esac
cat >> $SCRIPT << EOC

FINISHED=0
ERROR=0

echo waiting for job completion...

while [ "\$FINISHED" -lt 1 ]
do
    FINISHED="\$(grep exited ${LOGFILE} 2>/dev/null | wc -w)"
    FINISHED2="\$(grep 'Maximum Steps satisfied.' ${LOGFILE} 2>/dev/null | wc -w)"
    FINISHED3="\$(grep 'Maximum Physical Time satisfied.' ${LOGFILE} 2>/dev/null | wc -w)"
    INTERRUPTED="$(grep 'Stop File satisfied' ${LOGFILE} 2>/dev/null | wc -w)"
    if [ "\$INTERRUPTED" -gt 0 ]; then
	FINISHED=1
    fi
    if [ "\$FINISHED2" -gt 0 ]; then
	FINISHED=1
    fi
    if [ "\$FINISHED3" -gt 0 ]; then
	FINISHED=1
    fi
    ERROR="\$(grep errors ${LOGFILE} 2>/dev/null | wc -w)"
    if [ "\$ERROR" -gt 0 ]; then
	FINISHED=1
    fi
    if [ "\$FINISHED" -lt 1 ]; then
	sleep 5
    else
	FINISHED=1
    fi
done
EOC
#echo 'rm `cat delete.lst`' >> $SCRIPT

cat >> $SCRIPT << EOC
echo "...the job is complete." 
echo "saving job logs..." 
cp ${LOGFILE} ${JOBLOGDIR}/${INPUT}.$$.log

echo "Transferring the result files from the server. This may take a while..." 

# ------------------------------------------------------------------- #
# let's add some compression and display the files too                #
# ------------------------------------------------------------------- #

cd  ${SDIR}/${INPUT}.$$ && /usr/bin/scp -C -o 'Compression=yes' * ${FROM_HOST}:${CURDIR} 2>&1 
RC=$?

#
# -- comment for copyback testing. S. McKenna

if [ \$RC = 0 ] ; then
    echo "The files were succesfully copied to your directory" 
else
    echo "The input file results were left on the compute server" 
fi
mailx -s "Your Job ${INPUT_FILE} is Completed" \${USER} < ${SDIR}"/"${INPUT_FILE}.$$/"${LOGFILE}"
echo START_TIME=\$START_TIME
echo \$START_TIME >> $JOBLOGDIR/$INPUT.$$.log
echo
echo \$SUBMIT_SIZE >> $JOBLOGDIR/$INPUT.$$.log
echo
	
END_TIME="End time: \`date\`"
#SUBMIT_TIME="Submit time: \`date\`"
RESULTS_SIZE="After Results directory size: \`du -hs .\`"
echo RESULTS_SIZE=\$RESULTS_SIZE
echo \$END_TIME >> $JOBLOGDIR/$INPUT.$$.log
echo
echo \$RESULTS_SIZE >> $JOBLOGDIR/$INPUT.$$.log
echo
exit
EOC
chmod 755 $SCRIPT
}

for OPTION in $*
	do
	case $1 in
	-i)
		shift
		INPUT=$1
		shift
		;;
	-q)
		shift
		QUEUE=$1
		echo "QUEUE from hpcq = ${QUEUE}"
		shift
		;;
	-m)
		shift
		HOST=$1
		if [ "${HOST}" = "lsfchoice" ]
		then
			HOST=""
		fi
		shift
		;;
	-n)
		shift
		CPUS=$1
		shift
		;;
	-o)
		shift
		GLOBAL_MODEL=$1
		shift
		;;
	-p)
		shift
		PARALLEL=$1
		shift
		;;
	-v)
		shift
		STARCCM_VER=$1
		shift
		;;
	"" )
		;;
	*)
		echo Parameter not recognized.  Syntax:
		echo "$0 -i INPUT "
		exit 1
	esac
done

# Error checking:
[[ -z $INPUT ]] && {
	echo Input file was not specified, but is required
	echo Please enter Input file:
    read INPUT
    [[ ! -f $INPUT ]] && {
        echo "$INPUT does not exist in current directory - exiting"
        exit 1
    }
}

[[ -z $QUEUE ]] && {
        echo QUEUE was not specified, but is required
        echo Please enter Queue name - q1 or q2
	read QUEUE
}

[[ -n "$HOST" && ${HOST} != whqlx[023][0123458] ]] && {
        echo "Execution host not specified correctly"
        echo "Please enter a valid server name - whqlx02 or whqlx03"
	read HOST
	[[ -n "$HOST" && ${HOST} != whqlx0[23] ]] && {
		echo "Execution host not specified correctly  - exiting"
        	exit 1
	}
}

[[  $CPUS -lt 2  ||  $CPUS -gt 64  ]] && {
        echo "Number of processors not specified correctly"
        echo "Please enter a valid number between 2 and 12 "
	read CPUS
	[[  $CPUS -lt 2  ||  $CPUS -gt 16  ]] && {
        echo "Number of processors not specified correctly - exiting"
        exit 1
	}
}

echo "creating job submission script for input file $INPUT..."

#
# Create script and submit it:
#
#SCRIPT=/tmp/starccm.${LOGNAME}.$$
SCRIPT=${TMPDIR}/starccm.${LOGNAME}.$$
PWD=`pwd`
CURDIR=`echo $PWD | sed -e s/net/caehome/g`

#A hack to I, a non-CAE user, can test
CURDIR1=`echo $CURDIR/`

# Strip /tmp_mnt out of the CURDIR and SCRDIR directories if it exists

TMFND=`echo $CURDIR | grep -c tmp_mnt`
if [ $TMFND -gt 0 ]; then
  CURDIR=`echo $CURDIR | cut -b 9-`
fi
TMFND=`echo $SCRDIR | grep -c tmp_mnt`
if [ $TMFND -gt 0 ]; then
  SCRDIR=`echo $SCRDIR | cut -b 9-`
fi

#INPUT_FILE=$INPUT
FINISHED=0
#LOGFILE=`echo $INPUT_FILE | sed s/.inp$/.log/`
INPUT_FILE=$(echo ${INPUT} | awk -F/ '{print $NF}')
LOGFILE=`echo $INPUT_FILE | sed s/.inp$/.log/`
LOGFILE="output_$INPUT_FILE.txt"
Job_group=${INPUT_FILE}.$$
if [[ "${INPUT:0:1}" == "/" ]];then
    CURDIR="$(echo $INPUT | sed -e "s/${INPUT_FILE}//")"
fi

if [ ${VERBOSE} = "Y" ]; then
    echo "Input     :" ${INPUT}
    echo "Input File:" ${INPUT_FILE}
    echo "Job Group:"$Job_group
    echo "Current Directory:"$CURDIR
fi

f_write_script

chmod 755 $SCRIPT
#
echo "copying script to server..."

scp $SCRIPT $SERVER:${TMPDIR}
if [ $? -ne 0 ] ; then
    echo "Error copying script file to LSF head node host"
    exit 24
fi

COPY_SCRIPT=`basename ${SCRIPT}`

echo "submitting script to LSF on server..."
#
if [ ${VERBOSE} = "Y" ]; then
    echo $HOST
fi
[[ -z "$HOST" ]] && {
    HOST="oct_oct"
}

ssh $SERVER "chmod 755 $SCRIPT && . /usr/shared/lsf/conf/profile.lsf && bsub -f \"${TMPDIR}/${COPY_SCRIPT} > /tmp/${COPY_SCRIPT}\" -m \"${HOST}\" -g /$INPUT.$$ -n ${CPUS} -R \"span[hosts=1] \" -q $QUEUE /tmp/$COPY_SCRIPT"
# Now remove the script from /tmp on the submitting workstation
#
rm "$SCRIPT"
#
# End
