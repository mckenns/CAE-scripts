#!/bin/sh 
#
# ------------------------------------------------------------------- #
# this script -i JOB -q queue -m mem
# ------------------------------------------------------------------- #
#                                                                     #
# Job to submit NX Nastran to a queue.                                #
#                                                                     #
# ------------------------------------------------------------------- #
# Added TMPDIR, so we can use automount for LSF job submission        #
# ------------------------------------------------------------------- #
# Version 1102.2. S.McKenna 2020/01/17                                #
# Added email of logfile to submitting user, similar to Web page.     #
# ------------------------------------------------------------------- #
# Memory restriction removed. 11/21/2019. S.McKenna                   #
# No longer required and has to be the same as Web page.              #
# ------------------------------------------------------------------- #
# Set any defaults.
export HOST=$(uname -n)
export FROM_HOST=$(uname -n)

#MEM="1600mb"
SDIR="/scratch/home/$LOGNAME"
JOBLOGDIR=/scratch/joblogs/nxnastran
QUEUE=q3
SERVER=whqlx02
ERROR=0
#
[[ -z "${TMPDIR}" ]] && {
    TMPDIR=/tmp
}

# set lsf execution host to lsf "nxnast" defined group of nodes
# can be reset later for special cases/tests
HOST="nxnast"

# -------------------------------------------------------------- # 
# Function to check return codes.                                #
# -------------------------------------------------------------- # 
f_check_for_error () {
cat >> $SCRIPT << EOC

if [ \$? -ne 0 ] ; then
echo "Error copying input file to execution host"
exit 24
ERROR=1
fi
EOC
}

# -------------------------------------------------------------- # 
# Function to write the script to be copied and executed         #
# on the LSF execution host                                      #
# -------------------------------------------------------------- # 

f_write_script () {

echo "#!/bin/ksh " > $SCRIPT
cat >> $SCRIPT << EOC
#LM_LICENSE_FILE=28000@rocnt42
# obsolete and useless. installation determines the location of the license manager
# S. McKenna 01-09-2018. 
# s/be 28000@glugslic (aka rocnt423)
# 
LM_LICENSE_FILE=28000@glugslic
RC=0
ERROR=0

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

mkdir ${INPUT}.$$ || {
   echo "Error creating directory:"  ${SDIR}"/"${INPUT}.$$
   ERROR=1
}

cd ${INPUT}.$$ || {
    echo "Error switching to directory:"  ${SDIR}"/"${INPUT}.$$
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

cat >> $SCRIPT << EOC

if [ \$? -ne 0 ] ; then 
   echo "Error switching to directory:"  ${SDIR}"/"${INPUT}.$$ 
   exit 24 
   ERROR=1 
fi 
EOC

INPUT_COUNT=`grep -c ^INCLUDE $INPUT`
if [ $INPUT_COUNT -gt 0 ];
then
   grep ^INCLUDE $INPUT | while read INC FILE
   do
     INCNAME=`echo $FILE | tr -d '\015' | tr -d "'"` 
     echo "scp ${FROM_HOST}:$CURDIR/$INCNAME ." >> $SCRIPT
   done
fi
cat >> $SCRIPT << EOC
ls > delete.lst
if [ \${ERROR} = 0 ] ; then 
	/opt/${NXNAST_VER}/bin/nastran $INPUT scr=yes sdir=$SDIR old=yes bat=no sys1=65537 2>&1
else
	echo "Errors with job setup :"  ${SDIR}"/"${INPUT}.$$
	exit 24
fi
		
EOC
#echo 'rm `cat delete.lst`' >> $SCRIPT

cat >> $SCRIPT << EOC

# -- comment for copyback testing. S. McKenna
#echo ".. the job is complete." >> ${LOGFILE}
#echo "Saving job logs" >> ${LOGFILE}
echo "Execution host:"\$(uname -n)
echo ".. the job is complete." 
echo "Saving job logs" 

cp $LOGFILE $JOBLOGDIR/$INPUT.$$.LOG

#echo "copying files back to home directory" >> ${LOGFILE}
echo "copying files back to home directory" 

scp * ${FROM_HOST}:${CURDIR}

RC=$?

mailx -s "Your Job ${INPUT_FILE} is Completed" \${USER} <  ${SDIR}"/"${INPUT_FILE}.$$/"${LOGFILE}"

if [ \$RC = 0 ]; then
#   cd ${SDIR}
#   rm -r ${INPUT}.$$
#   echo "The files were succesfully copied to your directory" >> ${LOGFILE}
   echo "The files were succesfully copied to your directory" 
else
#   echo "The input file results were left on the compute server" >> ${LOGFILE}
   echo "The input file results were left on the compute server" 
fi

exit
EOC

chmod 755 $SCRIPT
}

# -------------------------------------------------------------- # 
# main processing                                                #
# -------------------------------------------------------------- # 
#
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
		shift
		;;
#	-m)
#		shift
#		MEM=$1
#		shift
#		;;
	-node)
		shift
		HOST=$1
		shift
		;;
	-v)
		shift
		NXNAST_VER=$1
		shift
		;;
	"" )
		;;
	*)
		echo Parameter not recognized.  Syntax:
#		echo $0 -i INPUT -q QUEUE -m MEM
		echo $0 -i INPUT -q QUEUE 
		exit 1
	esac
done

# -------------------------------------------------------------- # 
# Error checking:
# -------------------------------------------------------------- # 
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

#
# -------------------------------------------------------------- # 
# Create script and submit it:
# -------------------------------------------------------------- # 
#
SCRIPT=/tmp/${LOGNAME}.$$
PWD=`pwd`
CURDIR=`echo $PWD | sed -e s!/net/!/caehome/!g`
SCRDIR=`echo $HOME | sed -e s!/net/!/home/!g`
CURDIR1=`echo $CURDIR/`

#A hack to I, a non-CAE user, can test
[ "$(whoami)" = saarnam ] && CURDIR=`echo $PWD | sed -e s!/net/!/ugshome/!g`
[ "$(whoami)" = sunz ] && CURDIR=`echo $PWD | sed -e s!/net/!/ugshome/!g`

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
#LOGFILE=$(echo $INPUT | sed 's/.inp/.log/g' | sed 's/.dat/.log/g' | sed 's/.bdf/.log/g')
#LOGFILE=`echo $INPUT_FILE | sed s/.bdf$/.log/`
# ------------------------------------------------------------------------------ #
# Change any occurance of '*.bdf' OR '*.dat' to '*.log' for LOGFILE              #
# ------------------------------------------------------------------------------ #
LOGFILE=`echo $INPUT_FILE | sed 's/.bdf$/.log/g;s/.dat$/.log/g'`
Job_group=${INPUT_FILE}.$$
if [[ "${INPUT:0:1}" == "/" ]];then
    CURDIR="$(echo $INPUT | sed -e "s/${INPUT_FILE}//")"
fi

f_write_script

echo "copying script to server..."

scp $SCRIPT $SERVER:${TMPDIR}

if [ $? -ne 0 ] ; then 
   echo "Error copying script to LSF Head node server"
   exit 24 
   ERROR=1 
fi 
COPY_SCRIPT=`basename ${SCRIPT}`

echo "submitting script to LFS on server..."

#if [ ${NXNAST_VER} = "nxnastran11.0.2" ] ; then 
#    HOST="whqlx03"
#fi 

#ssh $SERVER "chmod 755 $SCRIPT && . /usr/shared/lsf/conf/profile.lsf && bsub -f \"${TMPDIR}/${COPY_SCRIPT} > /tmp/${COPY_SCRIPT} \" -m ${HOST} -q $QUEUE /tmp/${COPY_SCRIPT}"
ssh $SERVER ". /usr/shared/lsf/conf/profile.lsf && bsub -f \"${TMPDIR}/${COPY_SCRIPT} > /tmp/${COPY_SCRIPT} \" -m ${HOST} -q $QUEUE /tmp/${COPY_SCRIPT}"

#
# End
