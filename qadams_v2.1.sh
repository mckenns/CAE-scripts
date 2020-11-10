#!/bin/sh 
#
# qabaq -i JOB 
# ------------------------------------------------------------------- #
# Job to submit adams+ via LSF to whqlx34,or whqlx35 64-core nodes. #
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
# Version 1.0 S. McKenna 2020/03/20.                                  #
# New version to submit ADAMS jobs to q8adams LSF queue.              #
# ------------------------------------------------------------------- #
# Version 2.0 S. McKenna 2020/05/20.                                  #
# New version will parse a file $INPUT.adm, looking for MNF and MTX   #
# entries. Convert Windows type file paths to a local path, check if  #
# the files exist in the current directory, and copy these files to   #
# the compute node.                                                   #
# 1. The windows part was quite hard. I did it in a pre-process step, #
# instead on in the generated script like the Web developers did.     #
# 2. I check the files BEFORE submitting to LSF, as ADAMS does not    #
# return those types of errors to LSF, so the end user will get a     #
# 'completed' status. Hoefully, my version will tell them they need   #
# these files before submitting their job.                            #
# ------------------------------------------------------------------- #
# Version 2.1 S. McKenna 2020/05/22.                                  #
# New version try to clean up the file checking for included files in #
# the 'input file'.adm file.                                          #
# ------------------------------------------------------------------- #

HOST=`uname -n`
SDIR="/scratch/home/$LOGNAME"
JOBLOGDIR=/scratch/joblogs/adams
GLOBAL_MODEL=""
JOB_OPTIONS=""
PARALLEL=""
SERVER=whqlx02
SERVER=$(uname -n)
QUEUE=q8adams
HOST=""
CPUS=8
export let ERROR=0
#KMEMORYLIMIT=16777216
#
VERBOSE="N"
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
#
export CDLMD_LICENSE_FILE=1700@rocnt8 
#
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
# copy input file to execution host scratch home 

# ------------------------------------------------------------------ #
# Append to log file.                                                #
# ------------------------------------------------------------------ #

echo "Starting exec to logfile" >> ${LOGFILE}

exec 1>>${SDIR}"/"${INPUT_FILE}.$$"/"${LOGFILE}
exec 2>>${SDIR}"/"${INPUT_FILE}.$$"/"${LOGFILE}
echo "$(date) User ${USER} submited job $INPUT.$$" 
EOC
INCNAME=""
if [[ "${INPUT:0:1}" == "/" ]];then
    echo "scp ${FROM_HOST}:$INPUT ." >> $SCRIPT
    INCNAME=$( echo ${FROM_HOST}:$INPUT | awk -F. '{print $1}')
else
    echo "scp ${FROM_HOST}:$CURDIR/$INPUT ." >> $SCRIPT
    INCNAME=$( echo ${FROM_HOST}:/$CURDIR/$INPUT | awk -F . '{print $1}')
fi
f_check_for_error 

  if [ ${VERBOSE} = "Y" ]; then
    echo "INCNAME:" $INCNAME
   fi
#
# -------------------------------------------------------------------- #
# Copied logic from ABAQUS 'oldjob' to get the input file name         #
# for a regex copy of related files.                                   #
# the current logic basically copies everything in the source          #
# directory to the scratch on the compute node, which may be more      #
# than desired.                                                        #
# -------------------------------------------------------------------- #
#
# -------------------------------------------------------------------- #
# S. McKenna. Parse the acf file for 'file/model' entries and 'mnf'    #
#             files to copy to the target                              #
# -------------------------------------------------------------------- #
INPUT_COUNT=$(grep -c -i file/model $INPUT)
if [ $INPUT_COUNT -gt 0 ];
then
   grep -i file/model $INPUT | while read INC_LINE
   do
   # ------ trim out any control characters in the file name ----------- #
     INCNAME=$(echo $INC_LINE | cut -d= -f2 | cut -d, -f1 | tr -d '[[:cntrl:]]')".adm"
     if [ ${VERBOSE} = "Y" ]; then
         echo "INCNAME:" 
         echo "#INCNAME:" $INCNAME >> $SCRIPT
         echo "INCNAME:" 
     fi
     if [[ "${INCNAME:0:1}" = "/" ]];then
        echo "scp ${FROM_HOST}:$INCNAME ." >> $SCRIPT
     else
        echo "scp ${FROM_HOST}:$CURDIR/$INCNAME ." >> $SCRIPT
     fi
    f_check_for_error 
# ------------------------------------------------------------------- #
# TEST for Windows type embedded MNF files. Doesn't care if they      #
# exist or not. Just get the before and after and then modify the     #
# .adm file accordingly.                                              #
# ------------------------------------------------------------------- #
    for i in $(grep FILE $INCNAME | cut -d= -f2 | uniq );do 
	x=$(echo $i | awk -F \\ '{print $NF}') 
	if [ ${VERBOSE} = "Y" ]; then
	    echo "i:"$i 
	    echo "x:"$x 
	fi
     #   sed -n 's!${i}!${x}!g' $INCNAME 
    done
    
# ------------------------------------------------------------------- #
# Superceded by functions f_win_cnvt                                  #
# ------------------------------------------------------------------- #
#   grep FILE $INCNAME | cut -d= -f2 |  uniq | while read INC_NAME1
#	do
#	    echo "${INC_NAME1}" |  sed -i 's/\\/\\\\/g' 
#	    echo "#INC_NAME1:"$INC_NAME1 >> $SCRIPT
#        done
# ------------------------------------------------------------------- #
#                                                                     #
# ------------------------------------------------------------------- #
   grep FILE $INCNAME | cut -d= -f2 | tr -d "\015" |  uniq | cut -d= -f2 | awk -F '\\' '{print $NF}' | while read INC_NAME2
	do
	    if [ ${VERBOSE} = "Y" ]; then
	        echo "INC_NAME2:"$INC_NAME2
	        echo "#INC_NAME2:"$INC_NAME2 >> $SCRIPT
            fi
#	    echo "${INC_NAME2}" |  sed -i 's/\\/\\\\/g' 
            if [[ "${INC_NAME2:0:1}" = "/" ]];then
               echo "scp ${FROM_HOST}:$INC_NAME2 ." >> $SCRIPT
            else
               echo "scp ${FROM_HOST}:$CURDIR/$INC_NAME2 ." >> $SCRIPT
            fi
        done
   done
fi
cat >> $SCRIPT << EOC
# ------------------------------------------------------------------- #
# Hopefully, this is just a convoluted way to saying I want to delete #
#  my input file at the end of the job, and not I want to delete      #
# everything....                                                      #
# ------------------------------------------------------------------- #

ls *.acf > delete.lst
echo launching ADAMS job...
# ------------------------------------------------------------------- #
# Tested again on 2018/08/01. S.McKenna                               #
# ------------------------------------------------------------------- #
#echo "Check for ADAMS licenses - this will run forever"
#[ /usr/local/SAbin/lmutil lmstat -c 1700@rocnt8 -f MSCONE ] && {
#	echo "ADAMS license available"
#}

export MSC_LICENSE_FILE=1700@rocnt8

EOC
case ${ADAMS_VER} in

"2019.2")
echo "/opt/adams/2019.2/mdi -c ru-s i $INPUT ex 2>&1 || {
	echo "ADAMS job failed"
	exit 99
	}" >> $SCRIPT
;;

*)
echo "Unsupported ADAMS version" >> ${LOGFILE}
exit 99
;;

esac
cat >> $SCRIPT << EOC

echo waiting for job completion...

EOC
echo 'rm `cat delete.lst`' >> $SCRIPT

cat >> $SCRIPT << EOC
echo "...the job is complete." >> ${LOGFILE}
echo "saving job logs..." >> ${LOGFILE}
# 
\echo "\$(date) User ${USER} submited job name:$INPUT.$$"
cp ${LOGFILE} ${JOBLOGDIR}/${INPUT_FILE}.$$.log

echo "Transferring the result files from the server. This may take a while..." >> ${LOGFILE}
# ---------------------------------------------------------------------------- #
# Determine if the destination folder is already mounted via NFS, so we can    #
# copy it directly, instead of over the network.                               #
# ---------------------------------------------------------------------------- #
if [ -w "${CURDIR}" ]
then
    echo "local NFS mount available - copying locally" >> $LOGFILE
    echo "local NFS mount available - copying locally" >> $JOBLOGDIR/${INPUT_FILE}.$$.log
    cd  ${SDIR}/${INPUT_FILE}.$$ && /usr/bin/cp * ${CURDIR} 2>&1
else
    echo "local NFS mount not available - copying accross network" >> $LOGFILE
    echo "local NFS mount not available - copying accross network" >> $JOBLOGDIR/$INPUT.$$.log
    cd  ${SDIR}/${INPUT_FILE}.$$ && /usr/bin/scp -C -o 'Compression=yes' * ${FROM_HOST}:${CURDIR} 2>&1
fi
echo user is:"${USER}"
mailx -s "Your Job ${INPUT_FILE} is Completed" \${USER} <  ${SDIR}"/"${INPUT_FILE}.$$/"${LOGFILE}"

#
# ---------------------------------------------------------------------------- #
# -- comment for copyback testing. S. McKenna
# ---------------------------------------------------------------------------- #

if [ \$? = 0 ] ; then
    echo "The files were succesfully copied to your directory" >> ${LOGFILE}
else
    echo "The input file results were left on the compute server" >> ${LOGFILE}
fi

exit
EOC
chmod 755 $SCRIPT
}
# ---------------------------------------------------------------------------- #
# Start of Main line routine                                                   #
# ---------------------------------------------------------------------------- #
# Start of main line #
for OPTION in $*
	do
	case $1 in
	-i) shift; INPUT=$1; shift
		;;
	-q) shift; QUEUE=$1; echo "QUEUE from hpcq = ${QUEUE}"; shift
		;;
	-m) shift; HOST=$1;
		if [ "${HOST}" = "lsfchoice" ]
		then
			HOST=""
		fi
		shift
		;;
	-n) shift; CPUS=$1; shift
		;;
	-v) shift; ADAMS_VER=$1; shift
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
# ---------------------------------------------------------------------------- #
# Create script and submit it:
# ---------------------------------------------------------------------------- #
#
f_win_cnvt () {
# ---------------------------------------------------------------------------- #
# This function checks for Windows style entries in the ADAMS *.adm file       #
# and converts them to Unix files.                                             #
# e.g. ", MNF_FILE = C:\home/mckenns/fork.mnf" to ", MNF_FILE = fork.mnf"      #
# ---------------------------------------------------------------------------- #
#
        grep -n FILE $1  |  tr '\\' '/' | uniq -f 2|
        while read a ;
                do
                b=$(echo $a | awk -F: '{print $1}')
                x=$(echo $a | awk -F= '{print $2}')
                if [[ "${x:2:1}" = ":" ]];then
                        echo $a  is a windows file;
                        y=$(echo $a | awk -F= '{print $1}' | awk -F, '{print $2}')
                        z2=$(echo $a |  awk -F '/'  '{print $NF}')
                        z=$(echo ","$y" = "$z2)
                        sed -i "$b s|.*|$z|"  $1
        # ------------------------------------------------ #
        # now we can delete this line and replace it with  #
        # something Linux will understand.                 #
        # ------------------------------------------------ #
                fi;
	done
}
f_file_chk () {

local __my_error=$2
local let my_error=0
# ---------------------------------------------------------------------------- #
# This function extracts the file names from the "FILE" entries in the ADM     #
# file and checks if they exist in the current directory.                      #
# ---------------------------------------------------------------------------- #
        for x in $(grep FILE $1  |  tr '\\' '/' | uniq | awk -F= '{print $2}' | sed 's/.$//g')
            do
                if [[ ! $(ls $x 2>/dev/null) ]] ;then
       			echo "${x} file  does not exist in current directory."
			((my_error++))
	#		echo "Error:"$error
                fi
            done
	#echo "Error:"$my_error
	if [[ ${my_error} -gt 0 ]]
	then
	#    echo "Some ADM FILE files do not exist in current directory."
	#    echo "Error:"$my_error
            eval $__my_error="'$my_error'"
       #     exit 27
	fi
#echo $my_error
}

# ---------------------------------------------------------------------------- #
# Check for any windows type file references and remove them and replace them  #
# ---------------------------------------------------------------------------- #
INPUT_ADM="${INPUT/\.acf/\.adm}"
if [ ${VERBOSE} = "Y" ]; then
    echo $INPUT
    echo $INPUT_ADM
fi
#
f_win_cnvt $PWD/$INPUT_ADM

# ---------------------------------------------------------------------------- #
# Check if all of the references files are in the current directory            #
# ---------------------------------------------------------------------------- #

f_file_chk $PWD/$INPUT_ADM ERROR
#
#echo "Error:"$ERROR
if [[ $ERROR -gt 0 ]]
    then
       echo "<<<<<<<< this job will not run -exiting.                  >>>>>>"
       echo "<<<<<<<< Some ADM files do not exist in current directory.>>>>>>"
       echo "<<<<<<<< this job will not run -exiting.                  >>>>>>"
       exit 24
fi
# ---------------------------------------------------------------------------- #
# Create script and submit it:
# ---------------------------------------------------------------------------- #
#
# ---------------------------------------------------------------------------- #
#                                                                              #
# ---------------------------------------------------------------------------- #
#
SCRIPT=${TMPDIR}/adams.${LOGNAME}.$$
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

INPUT_FILE=$(echo ${INPUT} | awk -F/ '{print $NF}')
LOGFILE=`echo $INPUT_FILE | sed s/.acf$/.log/`
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
#remove exit after testing
#
if [ ${VERBOSE} = "Y" ]; then
    echo $HOST
fi
[[ -z "$HOST" ]] && {
    HOST="adams"
}
#exit
ssh $SERVER "chmod 755 $SCRIPT && . /usr/shared/lsf/conf/profile.lsf && bsub -f \"${TMPDIR}/${COPY_SCRIPT} > /tmp/${COPY_SCRIPT}\" -m \"${HOST}\" -g /$INPUT_FILE.$$ -n ${CPUS} -R \"span[hosts=1] \" -q $QUEUE /tmp/$COPY_SCRIPT"
# Now remove the script from /tmp on the submitting workstation
#
#rm "$SCRIPT"
#
# End
