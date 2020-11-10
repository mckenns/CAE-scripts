#!/bin/sh
#Job management: magma5.cgi
#Created by Nilesh Kumbhar
#Date: 26-Aug-2020
#Description: This file is a wrapper scripts. It creates a script according
#to job name and sends to the LSF head node. This gets all the inputs
#information from submit.py, including the application name, cpu, host name,
#input file and location of the where the results should go.
##############################################################################
################################################################################
############### Revision Histroy ###############################################
################################################################################
#Sl.No  Rev Date     Revised by   Details of Revision
# 1     08/27/2020   Nilesh Kumbhar NA
########/########################################################################
#
#This line is the main line that allows shell script to execute html command. must be
#added to the start of the file and must be followed by an empty line: echo ""
echo "Content-type: text/html"
echo ""
#
#The Head section below   defines the IE compatible, css and java script files.
 #link javascript files throught the the body also, but it will not be used for the
 #entire page. Same with css formating files.
 #The body section has an onload tag from javascript to open the file in light box.
 #
 /bin/cat
 EOM
 #following gives out network node hostname
 JOBLOGDIR=/scratch/joblogs/magma5
 #ABAQUS_VER="abq6111"
 #
 HOST=`uname -n`
 SERVER=whqlsf
 QUEUE="q64m"
 HOST="magma_hosts"
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
 -m)
 shift
 HOST=$1
 shift
 ;;
 -n)
 shift
 CPUS=$1
 shift
 ;;
 -v)
 shift
 MAGMA_VER=$1
 shift
 ;;
  -d)
  shift
  CURDIR=$1
  shift
  ;;
 -p)
 shift
 PARALLEL=$1
 shift
 ;;
  -u)
  shift
  USERNAME=$1
  shift
  ;;
  -t)
  shift
  STEP2FILE=$1
  shift
  ;;
 -r)
 shift
 RSTART=$1
 shift
 ;;
 -D)
 shift
 RESTARTDIR=$1
 shift
 ;;
 "" )
 ;;
 *)
 echo Parameter not recognized.  Syntax:
 echo $0 -i INPUT
 exit 1
 esac
 done
 echo "  User $USERNAME requested Magma5 Solver job submission. "
 #
 # Create script and submit it:
 #
 TMPDIR=/auto/tmp
 SCRIPT=/tmp/magma5.${USERNAME}.$$
 #
 SCRDIR="/home/${USERNAME}"
 CURDIR2=`dirname ${CURDIR}`
 scr_folder=/scratch/home/${CURDIR2#*/$(echo $CURDIR2 | awk -F\/ '{print $2}')/}
 CURDIR1=`echo $CURDIR/`
 #INPUT_FILE=$INPUT
 #
 #INPUT_FILE is actually a Folder
 INPUT_FILE=$INPUT
 FINISHED=0
 LOGS=/srv/www/hpcq/log/submitmagma5.log
 LOOPCOUNT=0
 INPUTFOLDER=`basename ${CURDIR}`
 LOGFILE=${INPUTFOLDER}.$$.log
 echo "#!/usr/bin/ksh" > $SCRIPT
 echo "ulimit -m 31457280 " >> $SCRIPT
 echo "MAIL=/usr/bin/mailx" >> $SCRIPT
 echo "RC=0" >> $SCRIPT
 echo "ERROR=0" >> $SCRIPT
 echo "if [[ ! -e /scratch/home/${USERNAME} ]];" >> $SCRIPT
 echo "then" >> $SCRIPT
 echo "mkdir /scratch/home/${USERNAME}" >> $SCRIPT
 echo "fi" >> $SCRIPT
 echo "cd /scratch/home/${USERNAME}" >> $SCRIPT
 #
 echo "mkdir -p ${scr_folder}/${INPUTFOLDER}" >> $SCRIPT
 echo "cd ${scr_folder}" >> $SCRIPT
 #
 echo "if [[ -e ${scr_folder}/${INPUTFOLDER} ]];then" >> $SCRIPT
 echo "cp -r ${CURDIR}/ ." >> $SCRIPT
 echo "else" >> $SCRIPT
 echo "scp -r whqcax:$CURDIR ." >> $SCRIPT
 echo "fi" >> $SCRIPT
 #
 #echo "ls -R ./> delete.lst" >> $SCRIPT
 #
 echo "if [ ! -e ${scr_folder}/${INPUTFOLDER} ]; then" >> $SCRIPT
 echo "echo "Job failed on the server, as input folder ${INPUTFOLDER} is not found. Input folder did not get copied to HPC server." > ${LOGFILE}" >> $SCRIPT
 #echo "echo "Job failed on the server, as input folder ${INPUTFOLDER} is not found. Input folder did not get copied to HPC server." > ${scr_folder}/${LOGFILE} && mail -s 'Job failed on the HPC server since ${INPUTFOLDER}.$$ : Input folder not Found' ${USERNAME}@aam.net  > $SCRIPT
 echo "else" >> $SCRIPT
 echo "/opt/MAGMA5/v5.4.1/LINUX64/bin/ms ${RSTART} -np ${CPUS} -proj ${scr_folder}/${INPUTFOLDER} > ${LOGFILE}" >> $SCRIPT
 echo "fi" >> $SCRIPT
 echo "FINISHED=0" >> $SCRIPT
 echo "ERROR=0"  >> $SCRIPT
 ####################################################################
 echo "echo waiting for job completion..." >> $SCRIPT
 echo "echo "\\#/opt/MAGMA5/v5.4.1/LINUX64/bin/ms ${RSTART} -np ${CPUS} -proj ${scr_folder}/${INPUTFOLDER}" >> ${LOGFILE}" >>$SCRIPT
 #echo "echo Execution host: \`uname -n\` >> /scratch$SCRDIR/${INPUT}.$$/$INPUT.$$.log" >> $SCRIPT
 echo "echo ...the job is complete." >> $SCRIPT
 echo "echo saving job logs..." >> $SCRIPT
 #
 #echo "cp ${LOGFILE} ${JOBLOGDIR}/" >> $SCRIPT
 #
 echo "cd ${scr_folder}/${INPUTFOLDER}/${INPUTFOLDER}" >> $SCRIPT
 #
 echo "if [[ -e $CURDIR ]];then" >> $SCRIPT
 echo "cp -r . $CURDIR2" >> $SCRIPT
 echo "else" >> $SCRIPT
 echo "scp -r . whqcax:$CURDIR2" >>$SCRIPT
 echo "fi" >> $SCRIPT
 ####################################################################
 echo "mail -s 'Your Job ${INPUTFOLDER} is Completed' ${USERNAME}@aam.net  > $SCRIPT
 echo "echo " >> $SCRIPT
 echo "RC=\$?" >> $SCRIPT
 echo "if [ \$? = 0 ] ; then" >> $SCRIPT
 echo "echo The files were successfully copied to your directory" >> $SCRIPT
 echo "else" >> $SCRIPT
 echo "mail -s 'Your Job ${INPUTFOLDER} files were not copied to your directory. Please raise the ticket to CCC.' ${USERNAME}@aam.net" >> $SCRIPT
 echo "fi" >> $SCRIPT
 echo "exit" >> $SCRIPT
 chmod 755 $SCRIPT
 cat ${SCRIPT} | ssh -o 'StrictHostKeyChecking no' -i /srv/www/.ssh/$USERNAME $USERNAME@$SERVER "cat > /auto${SCRIPT}"
 COPY_SCRIPT=`basename ${SCRIPT}`
 ######################
 echo "`date` User $USERNAME submited job ${INPUTFOLDER}.$$">>$LOGS
 ssh -i /srv/www/.ssh/$USERNAME $USERNAME@$SERVER "chmod 755 /auto$SCRIPT && dos2unix /auto$SCRIPT && . /usr/shared/lsf/conf/profile.lsf && bsub -f \"${TMPDIR}/${COPY_SCRIPT} > /tmp/${COPY_SCRIPT}\" -m \"${HOST}\" -n ${CPUS} -q $QUEUE /tmp/${COPY_SCRIPT}"
 #echo "ssh -i /srv/www/.ssh/$USERNAME $USERNAME@$SERVER \"chmod 755 /auto$SCRIPT && dos2unix $SCRIPT && . /usr/shared/lsf/conf/profile.lsf && bsub -f \"/tmp/${COPY_SCRIPT} > ${SCRIPT}\" -m \"${HOST}\" -g /$INPUT -n ${CPUS} -q $QUEUE $SCRIPT" >> $LOGS
 #
 echo "`date` $USERNAME submitted job name: ${INPUTFOLDER}.$$" >> $LOGS
 rm "$SCRIPT"
 /bin/cat
 EOM2