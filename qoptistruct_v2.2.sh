#!/bin/sh 
#
# Job to submit Optitruct+ via LSF to whqlx52.                       #
# ------------------------------------------------------------------- #
# Added TMPDIR, so we can use automount for LSF job submission        #
# ------------------------------------------------------------------- #
# Version 1.0 S. McKenna 2020/04/07.                                  #
# New version to submit Optistruct jobs to LSF queue 'qopti'.         #
# ------------------------------------------------------------------- #
# Version 2.0 S. McKenna 2020/05/20.                                  #
# New version to handle MMO jobs as well as 'standard' Optistruct     #
# jobs.                                                               #
# Optistruct 2019.1 will not use any GPUs, even if you tell it to.    #
#  it will ignore it, but not cause any errors.                       #
# Optistruct 2019.2 will use GPUs only if you include this in the     #
# optistruct command '-ngpu 1'. if you don't it will not use the GPU  #
# 'automatically' like ABAQUS jobs.                                   #
# In addition, MMO jobs will FAIL if you try to use '-ngpu 1'. They   #
# will ignore the GPU if it's present.                                #
# 'standard' jobs will use 10 cores.                                  #
# MMO jobs will use 4 cores with 4 threads each.                      #
# So you cannot run more than 1 MMO jobs on a 16/24 core node, but    #
# you can run 2x10 core 'standard' jobs on a single node with >16     #
# cores. e.g. the Dell 24 core systems.                               #
# ------------------------------------------------------------------- #
# Version 2.2 S. McKenna 2020/06/16				      #
# 'standard' jobs will now use 12 cores                               #
# For ‘regular’ Optistruct, it’s just                                 #
#                                                                     #
# "-ncpu 12"                                                          #
# e.g.                                                                #
#	/opt/optistruct/altair/scripts/optistruct -v 2019.1           #
#  -ncpu 12 -mpi -hostfile opt_hosts -file beam_test_file.fem         #
# -lic OPT -scr /scratch/home/mckenns"/"beam_test_file.fem.5298       #
#                                                                     #
# MMO 24 core jobs will use nt 6 -np 4                                #
# e.g.                                                                #
#	/opt/optistruct/altair/scripts/optistruct -v 2019.2           #
#  -mmo -nt 6 -np 4 -mpi -hostfile opt_hosts ${OPTIONS}               #
#  -file master.fem -lic OPT                                          #
#  -scr /scratch/home/mckenns"/"master.fem.5923a                      #
#                                                                     #
# And for 48 core MMO                                                 #
# MMO 48 core jobs will use                                           #
# e.g.                                                                #
#  	/opt/optistruct/altair/scripts/optistruct -v 2019.2           #
# -mmo -nt 8 -np 6 -mpi -hostfile opt_hosts -file master.fem -lic OPT #
# -scr /scratch/home/mckenns"/"master.fem.7233                        #
#                                                                     #
# for LSF just multiply the ‘-np’ by the ‘-nt’ and use that for the   #
#  LSF CPU number ‘-n  xxxx’ on the bsub command                      #
#                                                                     #
# ------------------------------------------------------------------- #

HOST=`uname -n`
SDIR="/scratch/home/$LOGNAME"
JOBLOGDIR=/scratch/joblogs/optistruct
SERVER=whqlsf
SERVER=$(uname -n)
QUEUE=qopti
HOST=""
CPUS=""
JOB_OPTIONS=""
GPU=""
OPTIONS=""

NVIDIA_CHECK="/usr/bin/nvidia-smi -L > /dev/null"
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
    SERVER="whqlsf"
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
#
MAIL=/usr/bin/mailx
RC=0
#
export ALTAIR_LICENSE_PATH="6200@rocnt401"
export PATH=/opt/optistruct/altair/mpi/linux64/intel-mpi/bin64:$PATH
export LD_LIBRARY_PATH=/opt/optistruct/altair/mpi/linux64/intel-mpi/lib64:$LD_LIBRARY_PATH
#export I_MPI_DEBUG=5
. /usr/shared/lsf/conf/profile.lsf

export TMPDIR="${SDIR}"/"${INPUT_FILE}.$$"
echo ${TMPDIR}
#

echo \$LSB_HOSTS

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
# ------------------------------------------------------------------ #
# Append to log file.                                                #
# ------------------------------------------------------------------ #

echo "Starting exec to logfile" >> ${LOGFILE}

exec 1>>${SDIR}"/"${INPUT_FILE}.$$"/"${LOGFILE}
exec 2>>${SDIR}"/"${INPUT_FILE}.$$"/"${LOGFILE}
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

# ------------------------------------------------------------------- #
# S. McKenna. Copy any 'ASSIGN' MMO files listed in the input file    #
# ------------------------------------------------------------------- #
INPUT_COUNT=`grep -c -i ASSIGN $INPUT`
if [ $INPUT_COUNT -gt 0 ];
then
   grep -i ASSIGN $INPUT | while read INC_LINE
   do
   # ------ trim out any control characters in the file name ----------- #
     INCNAME=$(echo $INC_LINE | cut -d, -f4 | tr -d '[[:cntrl:]]')

     if [[ "${INCNAME:0:1}" = "/" ]];then
        echo "scp ${FROM_HOST}:$INCNAME ." >> $SCRIPT
     else
        echo "scp ${FROM_HOST}:$CURDIR/$INCNAME ." >> $SCRIPT
     fi
    f_check_for_error 
    
   done
fi
# ------------------------------------------------------------------- #
# S. McKenna.                                                         #
# ------------------------------------------------------------------- #
# Possible MMO options                                                #
# .../scripts/optistruct inputfile.fem -v 2019.2.1 -nt 4 -np 4        #
# -mpi I -mmo -mpiargs ' -env ALTAIR_LICENSE_PATH 6200@admin          #
# -env LD_LIBRARY_PATH /altair/hw/2019/altair/mpi/./linux64/intel-mpi #
# /lib:/altair/hw/2019/altair/hwsolvers/common/bin/linux64' -hostfile #
# /var/spool/PBS/aux/4110.admin -scr /scratch/pbs.4110.admin.x8z      #
# -core IN                                                            #
# ------------------------------------------------------------------- #

cat >> $SCRIPT << EOC
# ------------------------------------------------------------------- #
# Hopefully, this is just a convoluted way to saying I want to delete #
#  my input file at the end of the job, and not I want to delete      #
# everything....                                                      #
# ------------------------------------------------------------------- #

ls *.fem > delete.lst
echo launching OPTISTRUCT job...
# Start Check for GPUs on systems. S.McKenna 05/09/2018

# ------------------------------------------------------------------- #
# S. McKenna. MMO jobs will not work with GPUS, so remove the option  #
# ------------------------------------------------------------------- #
# Start Check for GPUs on systems. S.McKenna 05/09/2018

\$NVIDIA_CHECK > /dev/null  && {
    OPTIONS="\${OPTIONS} -ngpu 1"
}
#
OPT="$( echo $JOB_OPTIONS | egrep -e '-mmo|-mpi' )"
RET=$?
if [ \${RET} = 0 ] ; then
	 OPTIONS=$( echo \$OPTIONS | sed -e 's/-ngpu 1//g')
	 OPTIONS=""
	 echo \$OPTIONS
fi
echo "LSB_DJOB_HOSTFILE:"\${LSB_DJOB_HOSTFILE}
\$(cat \${LSB_DJOB_HOSTFILE} | uniq > ./opt_hosts)
# ------------------------------------------------------------------- #
# Optistruct needs the local scratch folder on all the compute nodes  #
# that the job is to run on. Assuming 2 nodes, let's just create the  #
# folder on the second node listed under 'opt_hosts'.                 #
# Additionally, it seems like it needs the *.fem files, so let's copy #
# them too....... S.McKenna 06/12/2020                                #
# ------------------------------------------------------------------- #
#
EOC
echo 'for i in $(cat opt_hosts )' >> $SCRIPT
echo "do" >> $SCRIPT
echo "	ssh -q \$i mkdir ${SDIR}"/"${INPUT_FILE}.$$" >> $SCRIPT
echo "	scp *.fem \$i:${SDIR}"/"${INPUT_FILE}.$$" >> $SCRIPT
echo "done" >> $SCRIPT

cat >> $SCRIPT << EOC

[[  $CPUS -gt 25  ]] && {
     #JOB_OPTIONS="\${JOB_OPTIONS} -mpi i -hostfile \$LSB_DJOB_HOSTFILE"
     JOB_OPTIONS="\${JOB_OPTIONS} -mpi i -hostfile ./opt_hosts"
     echo "JOB_OPTIONS:" \$JOB_OPTIONS
}

echo "LSB_DJOB_HOSTFILE:"\${LSB_DJOB_HOSTFILE}
#
# Scratch directory should be the current working directory
#
SCR="${SDIR}"/"${INPUT_FILE}.$$"
echo $SCR
# ------------------------------------------------------------------- #
# Optistruct 2019.1 does not support GPUs, so don't use this option.  #
# Optistruct 2019.2 DOES support GPUs, so use this option.            #
# ------------------------------------------------------------------- #
case ${OPTISTRUCT_VER} in

"2019.1"|"2019.2")
	echo "/opt/optistruct/altair/scripts/optistruct -v ${OPTISTRUCT_VER} ${JOB_OPTIONS} \${OPTIONS} -file $INPUT_FILE -lic OPT -scr ${SDIR}"/"${INPUT_FILE}.$$"
	/opt/optistruct/altair/scripts/optistruct -v ${OPTISTRUCT_VER} ${JOB_OPTIONS} \${OPTIONS} -file $INPUT_FILE -lic OPT -scr ${SDIR}"/"${INPUT_FILE}.$$ || {
		echo "OPTISTRUCT job failed"
		echo user is:"${USER}"
		mailx -s 'Your Job '${INPUT_FILE}' Failed' \${USER} <  ${SDIR}"/"${INPUT_FILE}.$$/"${LOGFILE}"
		exit 99
		}
;;

*)
echo "Unsupported OPTISTRUCT version" >> ${LOGFILE}
exit 99
;;

esac

RET=$?
if [ \${RET} -gt  0 ] ; then
	echo "OPTISTRUCT job failed"
	echo user is:"${USER}"
	mailx -s 'Your Job '${INPUT_FILE}' Failed' \${USER} <  ${SDIR}"/"${INPUT_FILE}.$$/"${LOGFILE}"
	exit 99
fi
echo waiting for job completion...

EOC
#echo 'rm `cat delete.lst`' >> $SCRIPT

cat >> $SCRIPT << EOC
echo "...the job is complete." >> ${LOGFILE}
echo "saving job logs..." >> ${LOGFILE}
cp ${LOGFILE} ${JOBLOGDIR}/${INPUT_FILE}.$$.log

echo "Transferring the result files from the server. This may take a while..." >> ${LOGFILE}
# ---------------------------------------------------------------------------- #
# Determine if the destination folder is already mounted via NFS, so we can    #
# copy it directly, instead of over the network.                               #
# This is not working if you submit a job from e.g. /home/user. It will copy   #
# the results to /home/user on the COMPUTE Node, because the '-w' says so....  #
# something like this might work.                                              #
# S.McKenna 04/09/2020  					               #
# MAY be fixed below. Ugly but functional. took two days pretty much to do.    #
# Check if this works for PBO and EHQ                                          # 
# ---------------------------------------------------------------------------- #

[[ \$(echo "${CURDIR}" | grep "^/caehome") &&  -w "${CURDIR}"  ]] && {

	    echo "local NFS mount available - copying locally" >> $LOGFILE
	    echo "local NFS mount available - copying locally" >> $JOBLOGDIR/${INPUT_FILE}.$$.log
	    cd  ${SDIR}/${INPUT_FILE}.$$ && /usr/bin/cp * ${CURDIR} 2>&1

}

[[ \$(echo "${CURDIR}" | grep "^/caehome") &&  -w "${CURDIR}"  ]] || {

	    echo "local NFS mount not available - copying accross network" >> $LOGFILE
	    echo "local NFS mount not available - copying accross network" >> $JOBLOGDIR/$INPUT.$$.log
	    cd  ${SDIR}/${INPUT_FILE}.$$ && /usr/bin/scp -C -o 'Compression=yes' * ${FROM_HOST}:${CURDIR} 2>&1

}

echo user is:"${USER}"
tail -n 20 ${SDIR}"/"${INPUT_FILE}.$$/"${LOGFILE}" | mailx -s "Your Job ${INPUT_FILE} is Completed" \${USER} 

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
# ------------------------------------------------------------------- #
# Start of Main line routine                                          #
# ------------------------------------------------------------------- #
# Start of main line #

#echo $*
CPUS=""
for OPTION in $*
	do
	echo $1
	case $1 in
	-i) shift; INPUT=$1; shift ;;
	-q) shift; QUEUE=$1; echo "QUEUE from hpcq = ${QUEUE}"; shift ;;
	-m) shift; HOST=$1
		if [ "${HOST}" = "lsfchoice" ]
		then
			HOST=""
		fi
		shift
		;;
	-nt) shift; THREADS=$1; shift ;;
	-np) shift; PROCS=$1; shift ;;
	#-ncpus) shift; CPUS=$1; echo "CPUS:"$CPUS;shift ;;
	-ncpus) shift; CPUS=$1; shift ;;
	#-n) shift; CPUS=$1; echo "CPUS:"$CPUS;shift ;;
	-n) shift; CPUS=$1; shift ;;
	-j) shift; JOB_OPTIONS=${JOB_OPTIONS}" "$1; echo ${JOB_OPTIONS}; shift ;;
	-o) shift; GLOBAL_MODEL=$1; shift ;;
	-p) shift; PARALLEL=$1; shift ;;
	-v) shift; OPTISTRUCT_VER=$1;echo $OPTISTRUCT_VER; shift ;;
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
# ---------------------------------------------------------------------------- #
# Check JOB_OPTIONS for 'date=yyy:mm:dd:hh:mm'' 03/07/2019. S.McKenna
# ---------------------------------------------------------------------------- #
# Check for user entered date and time to submit LSF job . S.McKenna 06/03/2019
if [ ${VERBOSE} = "Y" ]; then
	echo "qoptistruct_v1.sh: check for date entry"
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

[[ -z "${BSUB_DATE}" ]] || {
        BSUB_DATE_REQUESTED=" -b ${BSUB_DATE}"
        JOB_OPTIONS=$(echo $JOB_OPTIONS | sed -e 's/date='"$BSUB_DATE"'//')
}
if [ ${VERBOSE} = "Y" ]; then
	echo "Job options:" $JOB_OPTIONS
fi

#\echo "LSB_DJOB_HOSTFILE:"${LSB_DJOB_HOSTFILE}

# ---------------------------------------------------------------------------- #
# Check JOB_OPTIONS for 'gpu=Y' 04/29/2019. S.McKenna
# ---------------------------------------------------------------------------- #

if [[ $(echo $JOB_OPTIONS | grep 'gpu=Y') ]];then 
	GPU=" && gpu"
	JOB_OPTIONS=$(echo "${JOB_OPTIONS}" | sed -e 's/gpu=Y/-ngpu 1/g')
fi

if [[ $(echo $JOB_OPTIONS | grep 'gpu=N') ]];then 
	GPU=" && !gpu"
	JOB_OPTIONS=$(echo "${JOB_OPTIONS}" | sed -e 's/gpu=N//g')
fi

if [ ${VERBOSE} = "Y" ]; then
    echo "Job Options::"$JOB_OPTIONS
    echo "Options::"$OPTIONS
fi

# ---------------------------------------------------------------------------- #
# Remove GPU parameter for MMO jobs.S.McKenna. as it conflicts with MPI        #
# ---------------------------------------------------------------------------- #
#
[[ $(echo $JOB_OPTIONS | grep 'mmo') ]] && { 
	JOB_OPTIONS=$(echo "${JOB_OPTIONS}" | sed -e "s/mmo/-mmo -nt ${THREADS} -np ${PROCS}/g")
#	JOB_OPTIONS=$(echo "${JOB_OPTIONS}" | sed -e "s/mmo/-mmo -nproc ${CPUS}/g")
	OPTIONS=$(echo "${OPTIONS}" | sed -e 's/-ngpu 1//g')
}
#
if [ ${VERBOSE} = "Y" ]; then
    echo "Job Options::"$JOB_OPTIONS
    echo "Options::"$OPTIONS
fi

[[ $(echo $JOB_OPTIONS | grep -e '-mmo') ]] || { OPTIONS=${OPTIONS}" -ngpu 1";}

if [ ${VERBOSE} = "Y" ]; then
    echo "Job Options::"$JOB_OPTIONS
    echo "Options::"$OPTIONS
fi
# ---------------------------------------------------------------------------- #
# If it's not an MMO job, create the '-ncpu ' option for normal jobs.          #
# ---------------------------------------------------------------------------- #
#
#echo " If it's not an MMO job, create the '-ncpu ' option for normal jobs. "
[[ $(echo $JOB_OPTIONS | grep -e '-mmo') ]] || { JOB_OPTIONS=${JOB_OPTIONS}" -ncpu ${CPUS}";}

if [ ${VERBOSE} = "Y" ]; then
    echo "NCPU Job Options::"$JOB_OPTIONS
    echo "Options::"$OPTIONS
fi
#[[ $(echo $JOB_OPTIONS | grep -e '-mpi') ]] || { JOB_OPTIONS=${JOB_OPTIONS}" -mpi -hostfile \$LSB_DJOB_HOSTFILE";}
[[ $(echo $JOB_OPTIONS | grep -e '-mpi') ]] || { JOB_OPTIONS=${JOB_OPTIONS}" -mpi -hostfile opt_hosts";}

if [ ${VERBOSE} = "Y" ]; then
    echo "MPI Job Options::"$JOB_OPTIONS
    echo "Job Options::"$JOB_OPTIONS
fi
# ---------------------------------------------------------------------------- #
# Create the LSF job submission script                                         #
# ---------------------------------------------------------------------------- #
#
echo "creating job submission script for input file $INPUT..."

#
# Create script and submit it:
#
SCRIPT=${TMPDIR}/optistruct.${LOGNAME}.$$
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
LOGFILE=`echo $INPUT_FILE | sed s/.fem$/.log/`
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
EXCLUSIVE=""
[[ "${CPUS}" -gt 16 ]] && { EXCLUSIVE=" -x "; }

[[ -z "$HOST" ]] && {
    HOST="optistruct"
}

echo "bsub ${EXCLUSIVE} ${BSUB_DATE_REQUESTED} -f \"${TMPDIR}/${COPY_SCRIPT} > /tmp/${COPY_SCRIPT}\" -m \"${HOST}\" -g /$INPUT_FILE.$$ -n ${CPUS} -R \" ${GPU}\" -q $QUEUE /tmp/$COPY_SCRIPT"

ssh $SERVER "chmod 755 $SCRIPT && . /usr/shared/lsf/conf/profile.lsf && bsub ${EXCLUSIVE} ${BSUB_DATE_REQUESTED} -f \"${TMPDIR}/${COPY_SCRIPT} > /tmp/${COPY_SCRIPT}\" -m \"${HOST}\" -g /$INPUT_FILE.$$ -n ${CPUS} -R \"select[type == any]  ${GPU}\" -q $QUEUE /tmp/$COPY_SCRIPT"
#
# Don't remove this script. it's an automount item. LSF uses it to copy to the compute node.
#
#rm "$SCRIPT"
#
# End
