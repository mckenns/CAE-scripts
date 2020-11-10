#!/bin/sh 
#
# ------------------------------------------------------------------- #
# Job to submit Abaqus Solver directly to abaqus on WHQLX02           #
# S.McKenna 07/12/2017 Version 4.2                                    #
# ------------------------------------------------------------------- #
# Features which have been added are as follows:-                     #
# (1) sources ina *.conf' file to determine which features to allow.  #
# (2) Option to submit Optistruct and STARCCM+ jobs from this menu.   #
#     Optistruct jobs are submitted to old Altair/HWUL cluster        #
#     STARCCM+ jobs are submitted to whqlx35 only (q64test) and the   #
#     two versions are offered.                                       #
# (3) Allows submission of ABAQUS 'explicit' jobs. (q16explicit)      #
#     Currently, these only run on the HPE 16 core servers, whqlx21,  #
#     whqlx32, and whqlx33.                                           #
# (4) Allows submission of ABQAQUS 16 core jobs with FORTRAN          #
#     subroutines to the new Dell 16 core servers.                    #
#     Additional file is selected and copied to the execution host    #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# S.McKenna 05/04/2017 Version 4                                      #
# Uses and inline 'at now' to allow LSF to submit another ABAQUS job  #
# instead of waiting for the results to be copied back                #
# ------------------------------------------------------------------- #
# New Functionality                                                   #
# S.McKenna 05/02/2017 Version 2                                      #
# This version is to utilized scp, ssh etc instead of scp, remsh      #
# to initiate the LSF jobs.                                           #
# Also included a function to write the script, write_script, instead #
# of the many 'echo' statements used before. Hopefully it's now       #
# easier to read and maintain.                                        #
#                                                                     #
# ------------------------------------------------------------------- #
# S.McKenna 08/16/2018 Version 2017.2a                                #
# ABAQUS 2017 version.                                                #
# Includes Submodels, includes, OLD Job, and EXPLICIT logic           #
# For EXPLICIT jobs, check the input file form the Hypermesh template #
# and add an ABAQUS option 'mp_mode=threads', which will allow these  #
# types of jobs to run on single Infiniband connected compute nodes,  #
# such as the new Dell servers.                                       #
# ------------------------------------------------------------------- #
# This version includes code to identify if the input file is in      #
# the current working directory, or is a fully-qualified path to      #
# an input file name. It also checks any included, or added , or      #
# optional file names are fully qualified or not.                     #
# ------------------------------------------------------------------- #
# S.McKenna 02/20/2019 Version 2017.3                                 #
# This version handles the 'explicit' LSF resource to make sure that  #
# mp_mode=threads ABAQUS jobs do not run on whqlx41 and whqlx42.      #
# Also, if cpus requested greater than 16, executes bsub -x for       #
# 'exclusive' jobs. the queues must also be 'EXCLUSIVE =Y'.           #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# S.McKenna 04/24/2019 Version 2017.3                                 #
# Added TMPDIR, so we can use automount for LSF job submission        #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# S.McKenna 04/29/2019 Version 2017.3.2                               #
# Added GPU option to use LSF GPU resources (not defined yet)         #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# S.McKenna 04/30/2019 Version 2017.3.3                               #
# Create /scratch/user on execution host if it doesn't exist.         #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# S.McKenna 05/03/2019 Version 2017.3.3                               #
# Modified to allow '-j gpu=Y' or '-j gpu=N' to be passed in....      #
# from /usr/local/bin/hpcq.v9x.                                       #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# S.McKenna 06/03/2019 Version 2017.3.3                               #
# Modified to allow '-j date=yyyy:mm:dd:hh:mm:ss' to be passed in     #
# from /usr/local/bin/hpcq.v11.                                       #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# S.McKenna 07/25/2019 Version 2017.3.4                               #
# Modified to allow '-j double=doff|both|explicit|constraint' to be   #
# passwd in from /usr/local/bin/hpcq.v11 or hpcq.v12                  #
# ------------------------------------------------------------------- #

VERBOSE="Y"
export FROM_HOST=$(uname -n)
if [ ${VERBOSE} = "Y" ]; then
	echo "Host name:" ${FROM_HOST}
fi
#
# ------------------------------------------------------------------- #
# Added TMPDIR, so we can use automount for LSF job submission        #
# scripts, so that jobs will continue in the event of a head node     #
# failover. TMPDIR is set in the hpcq.conf file, or defaulted to /tmp #
# ------------------------------------------------------------------- #
SDIR="/scratch/home/$LOGNAME"
JOBLOGDIR=/scratch/joblogs/abaqus
# 
GLOBAL_MODEL=""
PARALLEL=""
GPU=""
if [ -z ${HEAD_NODE} ]; then
	echo "Head Node not found"
	SERVER="whqlx02"
else
	SERVER=${HEAD_NODE}
fi

CPUS=4
ABAQUS_VER="abq6142"
NVIDIA_CHECK="/usr/bin/nvidia-smi -L > /dev/null"
IB_CHECK="/usr/sbin/ibstatus | grep ACTIVE > /dev/null "
KMEMORYLIMIT=31457280
JOB_OPTIONS=""
OPTIONS=""
#

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
ERROR=0 
# check for 2016Update4 Intel compiler
if [[ -d /opt/intel/compilers_and_libraries_2016.4.258/linux/bin/intel64 ]];then
    PATH=$PATH:/opt/intel/compilers_and_libraries_2016.4.258/linux/bin/intel64
else
# otherwise, must be the 2018Update1 compiler
    PATH=$PATH:/opt/intel/bin
fi
# Start Check for Abaqus2017 and GPU systems. S.McKenna 03/21/2018
if [[ -e /opt/abaqus/Commands/abq2017 ]];then
    ABAQUS_VER="abq2017"
else
    ABAQUS_VER="abq6142"
#   JOB_OPTIONS=""
fi
# End  Check for Abaqus2017 and GPU systems. S.McKenna 03/21/2018
#
# Start Check for GPUs on systems. S.McKenna 05/09/2018

\$NVIDIA_CHECK > /dev/null  && {
    #JOB_OPTIONS="${JOB_OPTIONS} gpus=1"
    OPTIONS="\${OPTIONS} gpus=1"
}
# 
# ----------------------------------------------------------- #
# Start creating and copying data for job.                    #
# ----------------------------------------------------------- #
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
# trim out any leading directories to get the job group,
# A.K.A. input file name plus PID
#
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
if [[ "${INPUT:0:1}" == "/" ]];then
    echo "scp ${FROM_HOST}:$INPUT ." >> $SCRIPT
else
    echo "scp ${FROM_HOST}:$CURDIR/$INPUT ." >> $SCRIPT
fi

f_check_for_error 

# ------------------------------------------------------------------- #
# S. McKenna. The following code may be useless.                      #
# ------------------------------------------------------------------- #
INPUT_COUNT=`grep -c -i include $INPUT`
if [ $INPUT_COUNT -gt 0 ];
then
   grep -i include $INPUT | while read INC_LINE
   do
   # ------ trim out any control characters in the file name ----------- #
     INCNAME=$(echo $INC_LINE | cut -d= -f2 | tr -d '[[:cntrl:]]')

     if [[ "${INCNAME:0:1}" = "/" ]];then
        echo "scp ${FROM_HOST}:$INCNAME ." >> $SCRIPT
     else
        echo "scp ${FROM_HOST}:$CURDIR/$INCNAME ." >> $SCRIPT
     fi
    f_check_for_error 
    
   done
fi
# ------------------------------------------------------------------- #
# S. McKenna. The preceding code may be useless.                      #
# ------------------------------------------------------------------- #
# ------------------------------------------------------------------- #
# S. McKenna. 08/27/2018                                              #
# ------------------------------------------------------------------- #
#                                                                     #
# Check the JOB_OPTIONS for 'Old Job'                                 #
# and create an scp to copy them to the execution host                #
# ------------------------------------------------------------------- #
#  maybe try something like this                                      #
#  for i in user oldjob globalmodel;do echo $i                        #
#      echo "user=ecaxxx.f oldjob=xxx abq2107 interactive             #
#            globalmodel=yyy.abc"                                     #
#             | sed -n 's/.*'$i'=//p' | awk '{print $1}'; done        #
#                                                                     #
# ------------------------------------------------------------------- #
#
for i in user globalmodel;do
    INCNAME=""
    INCNAME=$( echo $JOB_OPTIONS | sed -n 's/.*'$i'=//p' | awk '{print $1}')
    if [ ! -z "${INCNAME}" ];then
         if [[ "${INCNAME:0:1}" = "/" ]];then
            echo "scp ${FROM_HOST}:$INCNAME ." >> $SCRIPT
         else
            echo "scp ${FROM_HOST}:$CURDIR/$INCNAME ." >> $SCRIPT
         fi
        f_check_for_error
    fi        
done

for i in oldjob ;do
    INCNAME=""
    INCNAME=$( echo $JOB_OPTIONS | sed -n 's/.*'$i'=//p' | awk '{print $1}')
    if [ ! -z "${INCNAME}" ];then
         if [[ "${INCNAME:0:1}" = "/" ]];then
            echo "scp ${FROM_HOST}:$INCNAME"*" ." >> $SCRIPT
         else
            echo "scp ${FROM_HOST}:$CURDIR/$INCNAME"*" ." >> $SCRIPT
	 fi
        f_check_for_error
    fi        
done
#
# 
# ------------------------------------------------------------------- #
# S. McKenna. 08/27/2018                                              #
# ------------------------------------------------------------------- #

#echo $JOB_OPTIONS | grep 'globalmodel=' && {
#INCNAME=$( echo $JOB_OPTIONS | grep 'globalmodel=' | awk -F= '{print $2}' | awk '{print $1}')
#echo "scp ${FROM_HOST}:$CURDIR/$INCNAME ." >> $SCRIPT
# ------------------------------------------------------------------- #
# apparently not used by web page logic. So taking it out             #
# ------------------------------------------------------------------- #
#PRT_FILE=`echo ${INCNAME} | sed s/.odb$/.prt/`
# ------------------------------------------------------------------- #
#echo "scp ${FROM_HOST}:$CURDIR/${PRT_FILE} ." >> $SCRIPT
# ------------------------------------------------------------------- #
#f_check_for_error 
#}
if [ ! -z "${GLOBAL_MODEL}" ]
then
    if [[ "${GLOBAL_MODEL:0:1}" = "/" ]];then
        echo "scp ${FROM_HOST}:${GLOBAL_MODEL} ." >> $SCRIPT
        PRT_FILE=`echo ${GLOBAL_MODEL} | sed s/.odb$/.prt/`
        echo "scp ${FROM_HOST}:${PRT_FILE} ." >> $SCRIPT
    else
        echo "scp ${FROM_HOST}:$CURDIR/${GLOBAL_MODEL} ." >> $SCRIPT
        PRT_FILE=`echo ${GLOBAL_MODEL} | sed s/.odb$/.prt/`
        echo "scp ${FROM_HOST}:$CURDIR/${PRT_FILE} ." >> $SCRIPT
    fi
    f_check_for_error 
fi
cat >> $SCRIPT << EOC
ls *.inp > delete.lst
if [ "${VERBOSE}" = "Y" ]; then
    JOB_OPTIONS=$(echo ${JOB_OPTIONS}" verbose=3 ")
    echo ${ABAQUS_VER} ${JOB_OPTIONS} \${JOB_OPTIONS} 
    echo ${mp_mpirun_options} 
    echo "Options:"\${OPTIONS}
fi

if [ \${ERROR} = 0 ] ; then
    echo launching abaqus job...
    /opt/abaqus/Commands/\${ABAQUS_VER} job=$INPUT_FILE ${JOB_OPTIONS} \${OPTIONS} cpus=${CPUS} mp_host_split=2 ${PARALLEL} interactive 
    if [ \$? -ne 0 ] ; then
        echo 
        echo "Abaqus job failed with return code of" \$?
#        exit 99
    fi
else
    echo "Errors with job setup :"  ${SDIR}"/"${INPUT}.$$
    exit 24
fi

#FINISHED=1
ERROR=0

echo waiting for job completion...
EOC

echo rm '`cat delete.lst`' >> $SCRIPT

cat >> $SCRIPT << EOC
#echo "...the job is complete." >> ${LOGFILE}
#echo "saving job logs..." >> ${LOGFILE}
echo "Execution host:"\$(uname -n)
echo "...the job is complete." 
echo "saving job logs..." 
# comment this to see if this is overwriting the log file
cp ${LOGFILE} ${JOBLOGDIR}/${INPUT_FILE}.$$.log

echo "Transferring the result files from the server. This may take a while..." 

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
#
# < /scratch/home/malisep/CAE-2019-0928-T2XX_3p42_diff_case_Coast_5763Nm_4.inp.19422/CAE-2019-0928-T2XX_3p42_diff_case_Coast_5763Nm_4.inp.19422.log
#
if [ \$? = 0 ] ; then
    echo "The files were succesfully copied to your directory" 
else
    echo "The input file results were left on the compute server" 
fi
exit
#
#mail -s 'Your Job CAE-2019-0928-T2XX_3p42_diff_case_Coast_5763Nm_4.inp.19422 is Completed' malisep@aam.net < /scratch/home/malisep/CAE-2019-0928-T2XX_3p42_diff_case_Coast_5763Nm_4.inp.19422/CAE-2019-0928-T2XX_3p42_diff_case_Coast_5763Nm_4.inp.19422.log
#echo

EOC
chmod 755 $SCRIPT
#
}

# ---------------------------------------------------------------------------- #
# Start of main processing
# ---------------------------------------------------------------------------- #
INTERACTIVE="N"
FORTRAN=""

for OPTION in $*
	do
	case $1 in
	-i) shift; INPUT=$1; shift ;;
	-q) shift; QUEUE=$1; echo "QUEUE from hpcq = ${QUEUE}"; shift ;;
	-m) shift; HOST=$1; if [ "${HOST}" = "lsfchoice" ]
			    then
				HOST=""
			    fi
			    shift
		;;
	-n) shift; CPUS=$1; shift ;;
	-o) shift; GLOBAL_MODEL=$1; shift ;;
	-p) shift; PARALLEL=$1; shift ;;
	-v) shift; ABAQUS_VER=$1; shift ;;
	-j) shift; JOB_OPTIONS=${JOB_OPTIONS}" "$1; echo ${JOB_OPTIONS}; shift ;;
	"" )
		;;
	*)
		echo Parameter not recognized.  Syntax:
		echo "$0 -i INPUT "
		exit 1
	esac
done

# ---------------------------------------------------------------------------- #
# Error checking:
# ---------------------------------------------------------------------------- #
[[ -z $INPUT ]] && {
	echo Input file was not specified, but is required
	echo Please enter Input file:
    read INPUT
    [[ ! -f $INPUT ]] && {
        echo "$INPUT does not exist in current directory - exiting"
        exit 1
    }
}

[[ -z "$QUEUE" ]] && {
        echo QUEUE was not specified, but is required
        echo Please enter Queue name - q1 or q2
	read QUEUE
}

[[ ! -z "$GLOBAL_MODEL" ]] && {
        JOB_OPTIONS="globalmodel=${GLOBAL_MODEL}"
}

# ---------------------------------------------------------------------------- #
# Check JOB_OPTIONS for FORTRAN subroutine files. 03/08/2018. S.McKenna
# ---------------------------------------------------------------------------- #
if [[ $(echo $JOB_OPTIONS | grep 'user=') ]];then 
	FORTRAN="Y"
fi

# ---------------------------------------------------------------------------- #
# Check JOB_OPTIONS for 'gpu=Y' 04/29/2019. S.McKenna
# ---------------------------------------------------------------------------- #
if [[ $(echo $JOB_OPTIONS | grep 'gpu=Y') ]];then 
	GPU=" && gpu"
	JOB_OPTIONS=$(echo "${JOB_OPTIONS}" | sed -e 's/gpu=Y/gpu=1/g')
fi
if [[ $(echo $JOB_OPTIONS | grep 'gpu=N') ]];then 
	GPU=" && !gpu"
	JOB_OPTIONS=$(echo "${JOB_OPTIONS}" | sed -e 's/gpu=N//g')
fi

if [ ${VERBOSE} = "Y" ]; then
    echo "GPU options:"${GPU}
    echo "Job Options:"${JOB_OPTIONS}
fi

# ---------------------------------------------------------------------------- #
# Check JOB_OPTIONS for 'exclusive=y' 03/07/2019. S.McKenna
# ---------------------------------------------------------------------------- #
EXCLUSIVE=" "
if [[ $(echo $JOB_OPTIONS | grep 'exclusive=y') ]];then
        EXCLUSIVE=" -x "
        JOB_OPTIONS=$(echo $JOB_OPTIONS | sed -e 's/exclusive=y//')
fi

# ---------------------------------------------------------------------------- #
# Check JOB_OPTIONS for 'double=' 07/17/2019. S.McKenna
#  [double={explicit | both | off | constraint}]
# ---------------------------------------------------------------------------- #
PRECISION=" "
if [[ $(echo $JOB_OPTIONS | grep 'double') ]];then
        PRECISION=$( echo $JOB_OPTIONS | sed -n 's/.*'double'=//p' | awk '{print $1}')
#	PRECISION=$(echo " double="${PRECISION})
#        echo $PRECISION
        case ${PRECISION} in 
        off|both|explicit|constraint) echo ok ;; 
        *) echo bad precision;;
        esac
fi

# ---------------------------------------------------------------------------- #
# Check JOB_OPTIONS for 'date=yyy:mm:dd:hh:mm'' 03/07/2019. S.McKenna
# ---------------------------------------------------------------------------- #
# Check for user entered date and time to submit LSF job . S.McKenna 06/03/2019
if [ ${VERBOSE} = "Y" ]; then
	echo "qabaq2.2017.v3.5: check for date entry"
	echo "Job options:" $JOB_OPTIONS
fi
for i in date;do
    BSUB_DATE=""
    BSUB_DATE=$( echo $JOB_OPTIONS | sed -n 's/.*'$i'=//p' | awk '{print $1}')
done
[[ -z "${BSUB_DATE}" ]] || {
	echo $BSUB_DATE
    }

BSUB_DATE_REQUESTED=" "
#if [[ $(echo $JOB_OPTIONS | grep 'date=') ]];then
[[ -z "${BSUB_DATE}" ]] || {
        BSUB_DATE_REQUESTED=" -b ${BSUB_DATE}"
        JOB_OPTIONS=$(echo $JOB_OPTIONS | sed -e 's/date='"$BSUB_DATE"'//')
#fi
}
if [ ${VERBOSE} = "Y" ]; then
	echo "Job options:" $JOB_OPTIONS
fi

# ---------------------------------------------------------------------------- #
#                                                                              #
# ---------------------------------------------------------------------------- #
[[  $CPUS -lt 2  ||  $CPUS -gt 128  ]] && {
        echo "Number of processors not specified correctly"
        echo "Please enter a valid number between 2 and 128 "
	read CPUS
	[[  $CPUS -lt 2  ||  $CPUS -gt 128  ]] && {
        echo "Number of processors not specified correctly - exiting"
        exit 1
	}
}
#
echo "creating job submission script for input file $INPUT..."
#
# Create script and submit it:

#
[[ -z "${TMPDIR}" ]] && {
    TMPDIR=/tmp
}
SCRIPT=/tmp/hks.${LOGNAME}.$$
echo $SCRIPT
PWD=`pwd`
CURDIR=`echo $PWD | sed -e s/net/caehome/g`
# -------------------------------------------------------------------------- #
# New License calculation based on info from ABAQUS/DS. S.McKenna 2018/06/08 #
# -------------------------------------------------------------------------- #
x=$(echo "scale=4;(5 * (e(l(${CPUS})*0.422)))" | bc -l)
licreqd=${x%.*}
echo $licreqd

if [ ${VERBOSE} = "Y" ]; then
    echo "New License calculation"
    echo "new calculation with bc"
    echo "licreqd=${licreqd}"
fi
# -------------------------------------------------------------------------- #

echo "licreqd=${licreqd}"
#A hack to I, a non-CAE user, can test
[ "$(whoami)" = saarnam ] && CURDIR=`echo $PWD | sed -e s/net/ugshome/g`

SCRDIR=`echo $HOME | sed -e s/net/home/g`
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
LOGFILE=`echo $INPUT_FILE | sed s/.inp$/.log/`
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
#
echo "copying script to server..."
scp $SCRIPT $SERVER:${TMPDIR}
COPY_SCRIPT=`basename ${SCRIPT}`

echo "submitting script to LFS on server..."

EXCLUSIVE=""
[[ "${CPUS}" -ge 16 ]] && { EXCLUSIVE=" -x "; }

# -------------------------------------------------------------------------------- #
# if we move completely to /auto/tmp, the following command can be used instead.   #
# -------------------------------------------------------------------------------- #
if [ ${VERBOSE} = "Y" ]; then
	echo 'ssh $SERVER ". /usr/shared/lsf/conf/profile.lsf && bsub ${EXCLUSIVE} ${BSUB_DATE_REQUESTED} -f \"${TMPDIR}/${COPY_SCRIPT} > /tmp/${COPY_SCRIPT}\" -g /${Job_group} -n ${CPUS} -R \"select[abalic >= ${licreqd} ${GPU}] rusage[abalic=${licreqd}] \" -q $QUEUE /tmp/${COPY_SCRIPT}"'
fi
ssh $SERVER ". /usr/shared/lsf/conf/profile.lsf && bsub ${EXCLUSIVE} ${BSUB_DATE_REQUESTED} -f \"${TMPDIR}/${COPY_SCRIPT} > /tmp/${COPY_SCRIPT}\" -g /${Job_group} -n ${CPUS} -R \"select[abalic >= ${licreqd} ${GPU}] rusage[abalic=${licreqd}] \" -q $QUEUE /tmp/${COPY_SCRIPT}"

#
# End
# Now remove the script from /tmp on the submitting workstation
#
if [[ $(uname -n) !=  $SERVER ]];then
   rm "$SCRIPT"
fi #
#
# End
