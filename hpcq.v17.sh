#!/bin/sh
#
# ---------------------------------------------------------------------------- #
# Usage: hpcq -a application -i JOB -q queue                                   #
#                                                                              #
# Provide a single user interface to queue CAE jobs                            #
#                                                                              #
# ---------------------------------------------------------------------------- #
# SSH version on whqlx20. S. McKenna 04/20/2017                                #
# ---------------------------------------------------------------------------- #
# hpcq.menu.testing.                                                           #
# This version attempts to parameterize the various application versions in an #
# external file 'hpcq.conf.menu', to make it easier to add or modify           #
# different versions of                                                        #
# e.g. ABAQUS, NASTRAN, OPTISTRUCT, etc.                                       #
# ---------------------------------------------------------------------------- #
# Remove the references to the external config file for hwul2. This is now in  #
# the main configuration file and the values are copied if hwul2 is selected   #
# for STARCCM.                                                                 #
# ---------------------------------------------------------------------------- #
# Version 7.2 2018/10/18. S. McKenna                                           #
#   Completed dynamic menuing.  All options will be renumbered 1,2,3,4, etc    #
#   Abaqus changes                                                             #
#	FORTRAN, SUBMODELS, OLD JOB, Explict (mp_mode=threads)                 #
#       ALL files are MOVED back to the source.                                #
#       The log file is left on compute node                                   #
#       Allows for fully qualified file names, as well as current directory.   #
#   MAGMA5 submission from whqlx20 is enabled.                                 #
#       ALL files are copied back to the source                                #
# ---------------------------------------------------------------------------- #
# Version 7.2 2018/11/05 S.McKenna.                                            #
#       Enable the menu for the virtualization team to select a compute node   #
#       either a dedicated compute node or one of the general 16 core nodes.   #
# ---------------------------------------------------------------------------- #
# Version 7.4 2018/11/16 S.McKenna.                                            #
#       Use the menu functions for versions for Optistruct and STARCCM         #
#       applications.                                                          #
#       Shorten some of the if statements to [[ ]] && formats.                 #
#       General beautification of the script.                                  #
#       Fixed the BOL display which was not working for Linux.                 #
# ---------------------------------------------------------------------------- #
# Version 7.5 2018/11/20 S.McKenna.                                            #
#       Fixed the optional applications that are authorized by the users group #
#       membership. (optistruct, magma, starccm)                               #
#       Explicit jobs can run on any compute node with mp_mode=threads         #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# Version 7.6 2018/12/13 S.McKenna.                                            #
#       MAGMA updates to handle multiple servers (whqlx777 and whqlx49) and    #
#       CPUs 16 or 64, and hopefully different versions later..............    #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# Version 8 2019/01/23   S.McKenna.                                            #
#       This version allows the administrator to user 'P' instead of 'Y' or    #
#       'N' for the ABAQUS (tm) FORTRAN, EXPLICIT, OLDJOB, etc options and     #
#       create the appropriate script for submission.                          #
#       Values '1,Y,y' will select an option, '2,N,y' will not.                #
# ---------------------------------------------------------------------------- #
#
# ---------------------------------------------------------------------------- #
# Version 9 2019/01/23   S.McKenna.                                            #
#  This version is to add GPU as an option that will be used in LSF scheduling #
#  deprecated the 'EXPLICIT' processing as issue was resolved by disabling     #
#  second IB NIC and switch.                                                   #
# ---------------------------------------------------------------------------- #
#
# ---------------------------------------------------------------------------- #
# Version 10 2019/05/15   S.McKenna.                                           #
#  This version is to allow a user to supply their own 'hpcq.conf' file with   #
#  the variables to manipulate this script.                                    #
#  Only privileged users can do this because there is no error checking.       #
# ---------------------------------------------------------------------------- #
#
# ---------------------------------------------------------------------------- #
# Version 11 2019/05/31   S.McKenna.                                           #
#  This version is to allow a user to supply a date and time when to run their #
#  LSF job. Currently, only for ABAQUS solves.                                 #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# Version 12 2019/07/17   S.McKenna.                                           #
#  Added 'double' option to 16 core jobs.                                      #
#  fix to allow entering bsub date as a parameter. Cuurently only supports     #
#  -j date=today, -j date=tomorrow. Also requires '-b'.                        #
#  if '-b' only provided, the user will be prompted as before.                 #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# Version 14 2019/08/05   S.McKenna.                                           #
#  fix to allow entering bsub date as a parameter.                             #
#  support parameter entry with 'optional' date.                               #
#  if '-b' only provided, the user will be prompted as before.                 #
#  if '-b'{some date} entered, this will be validated.                         #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# Version 15 2019/08/30   S.McKenna.                                           #
#  fixed the duplication issue with passed in Job options.                     #
#  oldjob=xxx.odb was troublesome and has to be converted to oldjob=xxx        #
#  so I used 'E' to signal that oldjob was passed in via command line.         #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# Version 16 2020/01/31   S.McKenna.                                           #
#  Added the bsub date feature to STARCCM+ and NASTRAN application submission  #
#  fix to allow entering bsub date as a parameter.                             #
#  if '-b' only provided, the user will be prompted as before.                 #
#  if '-b'{some date} entered, this will be validated.                         #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# Version 17 2020/04/07   S.McKenna.                                           #
# Added ADAMS functionalitya                                                   #
# Added Optistruct 'in house' (runs on whqlx52 currently)                      #
# ---------------------------------------------------------------------------- #
export VALID_APP="N"
export CAE_APP=""
export CPUS=""
export HOST=""
export QUEUE=""
export FILE_SEARCH=""
export MAGMA5_VER=""
export STARCCM_VER=""
export JOB_OPTIONS=""
export DEFAULT_CONFIG_FILE="/usr/local/SAetc/hpcq.conf.menu17"

#. /usr/local/SAetc/hpcq.conf.menu9x
. /usr/local/SAetc/magma.env8

# comment after testing
VERBOSE="N"

if [ ${VERBOSE} = "Y" ];then
    echo "LSF CLUSTER:"$CLUSTER
    echo "HEAD Node:"$HEAD_NODE
    echo $CAE_APP
    echo $ABAQUS_VER
    echo $NXNAST_VER
    echo $HOST
    echo ${ABAQ_CPUS[@]}
    echo ${ABAQ_CPUSnum[@]}
    echo ${ABAQ_CPUSA[@]}
    echo ${ABAQ_CPUSque[@]}
    echo ${ABAQ_CPUShost[@]}
    echo ${ABAQUS_VER[@]}
    echo ${NXNAST_VER[@]}
    echo ${OS_VER[@]}
fi

VERBOSE="N"
SUB_HOST=`hostname`
export VALID_APP="N"

if [ ${VERBOSE} = "Y" ];then
    echo $(id -un)
    echo $(id -Gn)
fi
thisDir=$(cd `dirname ${0}`; pwd)
# ---------------------------------------------------- #
# DEPRECATED.                                          #
# handle newline differences between HP-UX and Linux   #
# ---------------------------------------------------- #
#if [ "`echo -n`" = "-n" ]
#then
#	BOL=
#	EOL="\c"
#else
#	BOL=-n
	BOL=""
	EOL="\n"
        BOL=""
        EOL=""

#fi
#
# ---------------------------------------------------- #
# Standard functions used and re-used in this script.  #
# ---------------------------------------------------- #
#
exceeded_retry_msg () {
	echo "You have exceeded the retry limit..."
	echo "The script is exiting"
	echo "To submit a job, restart the script."
}

invalid_choice_msg () {
	echo "Invalid choice - please select a valid option..."
}

check_loop_count () {
    ((LOOPCOUNT++))
    if [ $LOOPCOUNT -eq 3 ]
    then
    echo "exceeded_retry_msg "
    exit 1
    else
    echo "invalid_choice_msg"
    fi
}

f_date() {
# ---------------------------------------------------------------------------- #
# function validate a date entered via 'BSUBDATE' and return 'bsub_date'.      #
# ---------------------------------------------------------------------------- #
#
local __datein=$1
local myresult=""
eval bsub_date=\$${__datein}

if [ -n "${bsub_date}" ] ;then
    [[ $(/usr/bin/date --date "${bsub_date}"  2> /dev/null) ]] && {
        myresult=$(/usr/bin/date +%Y:%m:%d:%H:%M --date "${bsub_date}")
        display_date=$(/usr/bin/date --date "${bsub_date}"  2> /dev/null)
        BSUBDATE_ENTERED=true
    }
    [[ $BSUBDATE_ENTERED ]] && {
        JOB_OPTIONS=${JOB_OPTIONS}" -j date="${myresult}
    }
fi
}

f_get_menu_response() {
# ---------------------------------------------------------------------------- #
# General purpose function to handle menu display and selection, using two     #
# arrays, 'aprime' which contains the values to be chosen from, and 'bprime'   #
# which contains the text associated with the values, also menu question, and  #
# a variable name to be returned with the 'aprime' value the user selected.    #
# ---------------------------------------------------------------------------- #
#
local question=$1
local __version=$2
local myresult=''

version=${aprime[0]}

let LOOPCOUNT=0

let N1=1
while [[ "$version" = "" || ${#aprime[@]} != 1  ]] ;
do

cat << EOQ

$question:

EOQ
let k=$(echo ${#aprime[@]})
let j=0;i=1

while [[ ${j} < ${k} ]]
do
    echo "    $i.  ${bprime[$j]}"
    ((j++));((i++))
done
cat << EOQ

    q.  Quit
EOQ
echo Please enter your choice [${N1}]:
read N1
# --- translate YnNn to 1 or 2 ---- #
N1=$(echo ${N1} | tr "[YyNn]" "[1122]")

case $N1 in

[0-9])
	let Nx=$N1-1
    
        if [[ ${Nx} < ${k} ]];then
            myresult=(${aprime[${Nx}]})
            eval $__version="'$myresult'"
            break
        else
            invalid_choice_msg
        fi
        ;;
q)
        exit 0
        ;;
*)      check_loop_count
        ;;
esac

done
}

# ---------------------------------------------------------------------------- #
# Function to handle all input file options.                                   #
# ---------------------------------------------------------------------------- #
f_get_input_file() {
local loopcount=0
local inputname=""
local question=$1
local __filename=$2
local myresult=''
let LOOPCOUNT=0
while [[ "$inputname" = "" || "$myresult" = '' ]] ;
do
        echo "Select one of the following files or key in a complete file specification..."
        ls -1 ${FILE_SEARCH} 2> /dev/null | awk '{print "     "$0}'
        echo " "
        echo -e $BOL Please enter ${question} $EOL
        read inputname

        [[ ! -f $inputname ]] && {
	    ((LOOPCOUNT++))
            if [ $LOOPCOUNT -eq 3 ]
            then
                exceeded_retry_msg
                exit 1
            else
                echo "$inputname does not exist in current directory."
                echo "Enter a valid filename."
                inputname=""
            fi
        }
        myresult="${inputname}"

done # while [ "$INPUT" = "" ] ;
eval $__filename="'$myresult'"
} #f_get_input_file() 

f_ask_date () {
# ---------------------------------------------------------------------------- #
# Ask the user when they want to submit the job, if not today.                 #
# ---------------------------------------------------------------------------- #
aprime=( Y N )
bprime=( Yes No )

    while [ ! $BSUBDATE_ENTERED ] ;do
cat << EOQ

Enter a date when you want this job to run:
q. Quit
EOQ
echo Please enter a date :
    read datin
       case $datin in
         q)     break
          ;;
         *)
           bsub_date="";ANSWER="P"
           [ -n "${datin}" ] && {
                   [[ $(/usr/bin/date --date "${datin}"  2> /dev/null) ]] && {
                   bsub_date=$(/usr/bin/date +%Y:%m:%d:%H:%M --date "${datin}" )
                   display_date=$(/usr/bin/date --date "${datin}"  2> /dev/null)
                   while [ "$ANSWER" = "P" ] ;
                   do
                   f_get_menu_response "Please indicate if you want to use this date for your job ${display_date}"  ANSWER
                   done # while [ "$ANSWER= "" ]
                   [[ "$ANSWER" = "Y" ]] && {
                        if [[ ! -z ${JOB_OPTIONS} ]];then  JOB_OPTIONS=${JOB_OPTIONS}" -j date=$bsub_date"
                            else
                               JOB_OPTIONS=" -j date=$bsub_date"
                            fi
                        break;
                        }
                   [[ "$ANSWER" = "N" ]] && { ANSWER="P"; }
              }
           [  ! -n "${datin}" ] && {
              check_loop_count
                  }
           [[ $(/usr/bin/date --date "${datin}" ) ]] || {
              check_loop_count
                  }
              }
        ;;
   esac
done # while [ ! $BSUBDATE_ENTERED ]
}

# ---------------------------------------------------------------------------- #
# Display script usage                                                         #
# ---------------------------------------------------------------------------- #
#
f_usage()
{
echo "hpcq: ----------------------------"
echo "hpcq: batch script version 15.0   "
echo "hpcq: ----------------------------"

echo "cmd -v -a -i -f -q -m -n -p -j -s -c -b -h --"
echo
echo " -v verbose displays some additional messages."
echo " -a Application to run, Abaqus Check, Abaqus Solve"
echo "    Nastran, Optistruct, StarCCM+ etc...  "
echo " -i Input file name (current directory, not FQDN)"
echo " -f FORTRAN user subroutine file name"
echo " -q LSF batch queue name. e.g. q16"
echo " -m host"
echo " -n Number of CPUs . e.g. 16"
echo " -p parallel if other than domain"
echo " -j Job options"
echo " -s Model or small job"
echo " -c HPCQ configuration file entered by privileged user"
echo " -b ask for a date and time to run your job"
echo "    or enter a date immediately after -b   "
#echo " -f FORTRAN subroutine file name"
echo " -h help"
}

f_set_file_search ()
{
FILE_SEARCH=""
case $CAE_APP in

"abaqck")
        QUEUE="q1"
        FILE_SEARCH="*.inp"
        ;;
"abaq")
        FILE_SEARCH="*.inp"
        ;;
"adams")
        QUEUE="q8adams"
        FILE_SEARCH="*.acf"
        ;;
"nxnastran")
        QUEUE="q3"
        HOST="nxnast"
        FILE_SEARCH="*.bdf *.dat"
        ;;
"optistruct")
        echo $(id -Gn $UID )| grep optistruct> /dev/null && {
        QUEUE="workq"
        QUEUE="qopti"
        FILE_SEARCH="*.fem"
        }
        ;;
"magma")
        echo $(id -Gn $UID )| grep magma> /dev/null && {
        CPUS="16"
        CPUS=""
        HOST="lsfchoice"
#        MAGMA5_VER="v5.4.0"
        QUEUE="q64m"
        FILE_SEARCH="."
        }
        ;;
"starccm")
        echo $(id -Gn $UID )| grep starccm > /dev/null && {
        CPUS="64"
        QUEUE="q64"
        FILE_SEARCH="*.sim"
        }
        ;;
q)      exit 0
        ;;
*)      check_loop_count
        ;;
esac
}
# ---------------------------------------------------------------------------- #
# Check if current user is in an appropriate group to be able to use their own #
# configuration file.                                                          #
# ---------------------------------------------------------------------------- #
#
HPCQ_CONFIG_FILE="${DEFAULT_CONFIG_FILE}"

if [ ! -r "${HPCQ_CONFIG_FILE}" ] ; then
    echo "Error configuration file "${HPCQ_CONFIG_FILE}" not found, or not readable"
    ERROR=1
    exit 24
fi

. ${HPCQ_CONFIG_FILE}
. /usr/local/SAetc/magma.env8
BOL=""
EOL=""

HPCQ_CONFIG_FILE_Entered=false

#echo "CAE_APP:"$CAE_APP
#echo start of parameter entry

HPCQ_CONFIG_FILE_Entered=false
# ---------------------------------------------------------------------------- #
# Setup the option string. '-b' will now have an 'optional' argument           #
# ---------------------------------------------------------------------------- #

TEMP=$(getopt -o vha:b::i:f:q:m:n:j:p:s:c: -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"
# ---------------------------------------------------------------------------- #
# Start of parsing the command line options                                    #
# ---------------------------------------------------------------------------- #

while true ; do
        case $1 in
            -v) VERBOSE="Y" ; shift ;;
            -a) APP=1; CAE_APP=$2 ;shift 2 ;;
            -b) case "$2" in
                        "") ASK_DATE=1;echo "Option b - no arguement";shift 2;;
                        *)  BSUBDATE="$2";echo "Option b, argument \`$2'" ;f_date BSUBDATE JOB_OPTIONS; shift 2 ;;
                esac ;;
            -i) INPUT_ENTERED=1; INPUT=$2 ;shift 2 ;;
            -f) FORTRAN="Y"; INPUT2=$2 ;shift 2 ;;
            -q) QUEUE_ENTERED=1; QUEUE=$2 ;shift 2 ;;
            -j) JOBOPTIONS_ENTERED=1; JOB_OPTIONS=${JOB_OPTIONS}" -j "$2 ;shift 2 ;;
            -m) HOST_ENTERED=1; HOST=$2 ;shift 2 ;;
            -n) CPUS_ENTERED=1; CPUS=$2 ;echo "CPUS:"${CPUS};shift 2 ;;
            -p) PARALLEL_ENTERED=1; PARALLEL=$2 ;echo "PARALLEL:"${PARALLEL};shift 2 ;;
            -s) SMALL_JOB_ENTERED=1; SMALL_JOB=$2 ;echo "SMALL_JOB:"${SMALL_JOB};MODTEST="Y";shift 2 ;;
            -c) HPCQ_CONFIG_FILE_Entered=true;HPCQ_CONFIG_FILE=$2 ;shift 2 ;;
            -h) f_usage; exit ;;
            --) shift     ; break ;;
        esac
        #
        # submit to correct CAE application
        #
done
echo "Remaining arguments:"

for arg do echo '--> '"\`$arg'" ; done
#echo $JOB_OPTIONS
#echo $BSUBDATE
#
        # submit to correct CAE application
        #
        case $CAE_APP in

        a|aba|abaq|abaqus)
                CAE_APP="abaq"
                ;;
        ack|asynwax|abasyn|abaqck)
                CAE_APP="abaqck"
                ;;
        adams)
                CAE_APP="adams"
                ;;
        nx|nxnast|nxnastran)
                CAE_APP="nxnastran"
                ;;
        os|opti|optistruct)
                echo $(id -Gn $UID )| grep optistruct> /dev/null && {
                CAE_APP="optistruct"
                }
                ;;
	magma)
        	echo $(id -Gn $UID )| grep magma> /dev/null && {
                CAE_APP="magma"
                }
                ;;
        st|star|starccm)
                echo $(id -Gn $UID )| grep starccm > /dev/null && {
                CAE_APP="starccm"
                }
                ;;
        "")
                ;;
        *)
                echo
                echo Unrecognized application.  Available applications are:
                echo "abaqus abaqck(syntax check) nxnastran optistruct(runs on hwul) StarCCM Magma"
                echo "To submit a job, restart the script."
                echo
                exit 1
                ;;
        esac

[[ -z "$CAE_APP" ]] || {
    f_set_file_search
}
#done # while [ $# -gt 0 ]; do

if [ ${VERBOSE} = "Y" ];then
    echo $VERBOSE
    echo $APP=1; echo $CAE_APP
    echo $INPUT_ENTERED=1; echo $INPUT
    echo $QUEUE_ENTERED=1; echo $QUEUE
    echo $JOBOPTIONS_ENTERED=1; echo $JOB_OPTIONS
    echo $MEMORY_ENTERED=1; echo $MEMORY
    echo $PARALLEL_ENTERED=1; echo $PARALLEL
    echo $CPUS_ENTERED=1; echo $CPUS
    echo $HPCQ_CONFIG_FILE_Entered;echo $HPCQ_CONFIG_FILE
fi
#echo "CAE_APP:" $CAE_APP

[[ "${HPCQ_CONFIG_FILE_Entered}" = true ]] && {
    if [ ! -e  "${HPCQ_CONFIG_FILE}" ];then
        HPCQ_CONFIG_FILE="${DEFAULT_CONFIG_FILE}"
    else
        echo $(id -Gn $UID )| grep cae_adm > /dev/null  || { HPCQ_CONFIG_FILE="${DEFAULT_CONFIG_FILE}" ; }
    fi
#    echo $HPCQ_CONFIG_FILE_Entered;echo $HPCQ_CONFIG_FILE

    if [ ! -r "${HPCQ_CONFIG_FILE}" ] ; then
        echo "Error configuration file "${HPCQ_CONFIG_FILE}" not found, or not readable"
        ERROR=1
        exit 24
    fi

. ${HPCQ_CONFIG_FILE}
BOL=""
EOL=""

}

# ---------------------------------------------------------------------------- #
# Execute prompting version since user didn't provide parameters               #
# ---------------------------------------------------------------------------- #
USER=`whoami`
let LOOPCOUNT=0
# ---------------------------------------------------------------------------- #
# Main loop to display and read terminal input                                 #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# align the menu for approved applications only to make it flexible            #
# ---------------------------------------------------------------------------- #
[[ -z "$CAE_APP" ]] && {
    let i=0;j=0;x=();y=()
    let k=$(echo ${#CAE_APPS[@]})
    while [[ ${i} -lt ${k} ]]  
    do
        [[ ${CAE_APPS_OK[$i]} = 'Y' ]] && {
             x[$j]=${CAE_APPS[$i]}  
             y[$j]=${CAE_APPSA[$i]} 
             ((j++))
    }
        ((i++))
    done

    aprime=(${x[@]})
    bprime=("${y[@]}")
    let LOOPCOUNT=0
    if [[ ${#aprime[@]} = 1 ]];then
        CAE_APP=${aprime[0]}
        echo 
        echo ${bprime[0]}
    fi

    while [[ "$CAE_APP" = "" && ${#aprime[@]} != 1 ]] ;
    do
        f_get_menu_response "$BOL Please choose one of the following applications [2]:$EOL" CAE_APP
    done # while [ "$CAE_APP" = "" ] ;
}

f_set_file_search

#
# ---------------------------------------------------------------------------- #
# common code to setup the defaults for the applications selected              #
# ---------------------------------------------------------------------------- #
#
# ---------------------------------------------------------------------------- #
# OptiStruct application                                                       #
# ---------------------------------------------------------------------------- #
#
if [[ "$CAE_APP" = "optistruct" ]] 
then 
    echo $(id -Gn $UID )| grep optistruct> /dev/null && {
        VALID_APP="Y"
        HOST="whqlx02"

        OS_VER=${OS_VERS[0]}

        aprime=(${OS_VERS[@]})
        bprime=("${OS_VERSA[@]}")
        f_get_menu_response "Please chose Optistruct version " OS_VER

        aprime=();bprime=()
        aprime=( lsfchoice hwul2 )
        bprime=();let i=0;let k=$(echo ${#OS_Cluster[@]})
    
        while [[ $i -lt $k ]];do bprime[$i]="$OS_VER  ${OS_Cluster[$i]}"; ((i++)); done

        f_get_menu_response "Please chose Cluster " HOST

        if [ ${VERBOSE} = "Y" ];then
            echo "Optistruct Version:" $OS_VER
            echo "aprime:" ${aprime[@]} ":" ${#aprime[@]}
            echo "bprime:"${bprime[@]} ":" ${#bprime[@]}
            echo "Cluster Host:" ${HOST}
        fi
#

# ---------------------------------------------------------------------------- #
# Check the Job Options entered before instantiating menus                     #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# sed code. Will print anything after {$i}= that you pipe in. I can use this   #
# for aaa=123 type options.                                                    #
# for 'gpu' echo "gpu=Y" | sed -n 's/.*'gpu'=//p' | tr '[:lower:]' '[:upper:]  #
# ---------------------------------------------------------------------------- #
    GPU_ENTERED=false
    for i in mmo cpus gpu ;do
        INCNAME=$( echo $JOB_OPTIONS | sed -n 's/.*'$i'=//p' | awk '{print $1}')
        if [ -n "${INCNAME}" ];then
            case ${i} in
		mmo)
		MMO="Y"; 
		JOB_OPTIONS=$(echo $JOB_OPTIONS | sed -n 's/.*'$i'=Y//p'  )
		;;
		cpus)
		CPUS_ENTERED=1;let NCPUS=$INCNAME 
		;;
		gpu)
		GPU=$(echo $JOB_OPTIONS | sed -n 's/.*'$i'=//p' | awk '{print $1}' | tr '[:lower:]' '[:upper:]' )
		GPU_ENTERED=true
		echo "gpu option is:" $GPU
		;;
		*)
		continue
		;;
	   esac
	fi
    done # for i in mmo cpus gpu #
    if [ ${VERBOSE} = "Y" ];then
       echo "MMO:"$MMO
       echo "CPUS:"$NCPUS
       echo "GPU:"$GPU
       echo $CPUS_ENTERED=1; echo $CPUS
       echo "JOB OPTIONS:" ${JOB_OPTIONS}
    fi
#
# ---------------------------------------------------------------------------- #
# check for MMO option job                                                     #
# ---------------------------------------------------------------------------- #

#    [[ -z $MMO ]] && MMO=""

    [[ -z $MMO ]] && MMO=${OS_MMO[0]}
    aprime=( Y N )
    bprime=( Yes No )

    while [ "${MMO}" = "P" ] ;
    do
        f_get_menu_response "Please chose if you want to submit an OPTISTRUCT MMO job"  MMO
    done # while [ "$MMO= "" ] ;
    
    [[ ${VERBOSE} = "Y" ]] && { echo "MMO:" ${MMO}; }

# ---------------------------------------------------------------------------- #
# Big loop to check for Optistruct MMO options -mmo -nt x -np y  (defaults)    #
# ---------------------------------------------------------------------------- #

    [[ ${MMO} = "Y"  ]] && {
	JOB_OPTIONS=$JOB_OPTIONS" -j mmo -nt 4 -np 4"

# ---------------------------------------------------------------------------- #
# check for MMO option job                                                     #
# ---------------------------------------------------------------------------- #

    if [ ${VERBOSE} = "Y" ];then
        echo "MMO:" ${MMO}
        echo "JOB OPTIONS:" ${JOB_OPTIONS}
    fi
#
# ---------------------------------------------------------------------------- #
# OS_THREADS=( Y Y ) # OS_THREADSnum=( 4 8 ) # OS_THREADSA=( 'Four' 'Eight' )
# ---------------------------------------------------------------------------- #
#
    [[ ${MMO} = "Y"  ]] && {
#    	THREADS=""
	let THREADS=0
#
# ---------------------------------------------------------------------------- #
# Ask for any change to number of MMO threads   ( -nt 4 )                      #
# ---------------------------------------------------------------------------- #
#
	aprime=(${OS_THREADSnum[@]})
	bprime=("${OS_THREADSA[@]}")
	while [ "$THREADS" = 0 ] ;
	do
	    f_get_menu_response "Enter the number of OPTISTRUCT THREADS (default 4) "  THREADS
	done # while [ "$THREADS= "" ] ;
    } # end  of Threads loop
# ---------------------------------------------------------------------------- #
# Change the '-nt 4' on the JOB_OPTIONS string to whatevee was picked          #
# ---------------------------------------------------------------------------- #
    JOB_OPTIONS=$(echo $JOB_OPTIONS | sed -n -e "s/-nt 4/-nt ${THREADS}/p"  )
#
# ---------------------------------------------------------------------------- #
# OS_PROCS=( Y Y ) # OS_PROCSnum=( 4 8 ) # OS_PROCSA=( 'Four' 'Eight' )
# ---------------------------------------------------------------------------- #
#
    [[ ${MMO} = "Y"  ]] && {
	let PROCS=0
# ---------------------------------------------------------------------------- #
# Ask for any change to number of MMO processes ( -np 4 )                      #
# ---------------------------------------------------------------------------- #
	aprime=(${OS_PROCSnum[@]})
	bprime=("${OS_PROCSA[@]}")
	while [ "$PROCS" = 0 ] ;
	do
	    f_get_menu_response "Enter the number of  OPTISTRUCT MMO PROCS (default 4) "  PROCS
	done # while [ "$PROCS= "" ] ;
	} # end of PROCS loop
    JOB_OPTIONS=$(echo $JOB_OPTIONS | sed -n -e "s/-np 4/-np ${PROCS}/p"  )
#
    let CPUS=( ${THREADS} * ${PROCS} )
    if [ ${VERBOSE} = "Y" ];then
	echo "MMO:" ${MMO}
	echo "JOB OPTIONS:" ${JOB_OPTIONS}
	echo "CPUS:" ${CPUS}
    fi
   } # loop [[ ${MMO} = "Y"  ]] && {
# ---------------------------------------------------------------------------- #
# End of big MMO loop.                                                         #
# ---------------------------------------------------------------------------- #
# ---------------------------------------------------------------------------- #
# Check for number of Optistruct CPUS/cores to use (regular OPT only)          #
# ---------------------------------------------------------------------------- #
    [[ ${MMO} != "Y"  ]] && {
    [[ ${VERBOSE} = "Y" ]] && { echo :Entering CPU loop;}

#   CPUS=10  # Default value that ALTAIR suggested
    DEF_CPU=${CPUS}

    x=();y=();cpus=()
    let j=0;let i=0;let k=${#OS_CPUS[@]}
#   Make it more flexible by counting the CPU options array

    while [[ ${i} -lt ${k} ]];do
        if [[ ${OS_CPUS[$i]} = 'Y' ]] ; then
                x[$j]=${OS_CPUS[$i]}
                y[$j]=${OS_CPUSA[$i]}
                cpus[$j]=${OS_CPUSnum[$i]}
                ((j++))
        fi;
        ((i++))
    done

    DEF_CPU=10

    let LOOPCOUNT=0
    if [ ${VERBOSE} = "Y" ];then
	echo ${x[@]}
	echo ${y[@]}
	echo ${cpus[@]}
    fi

    while [ "$CPUS" = "" ];
    do
cat << EOC

Enter the number of processors to use:

EOC

    let k=$(echo ${#x[@]})
    let i=1;j=0

    while [[ ${j} -lt ${k} ]]
    do
    echo "    ${i}.  ${y[$j]}"
    ((j++));((i++))
    done

cat << EOC
    q.  Quit
EOC

echo Please enter your choice :
    read N3
    if [ "$N3" = "" ]; then
        N3=$DEF_CPU
    fi
    let Nx=$N3-1

    case $N3 in

    1|2)
        if [[ ${Nx} -lt ${k} ]] ; then
            CPUS=${cpus[${Nx}]}
            QUEUE=${que[${Nx}]}
#            [[ ${GPU} = "N" ]] && { GPU=${gpus[${Nx}]};}
#            HOST=${mhost[${Nx}]}
            if [ ${VERBOSE} = "Y" ];then
                echo "You picked:${CPUS} CPUS for queue:${QUEUE} with JOB_OPTIONS:${JOB_OPTIONS} or GPUs=${GPU} on HOST:${HOST}"
            fi
        else
            echo "invalid_choice_msg"
        fi
        ;;
    q)  exit 0
        ;;
    *)  check_loop_count
        ;;
    esac

    done # while [ "$CPUS" = "" ];

    [[ -z ${CPUS} ]] || { 
    	JOB_OPTIONS=$(echo $JOB_OPTIONS" -ncpus ${CPUS}") 
    }

    }  # MMO != "Y"
#
# ---------------------------------------------------------------------------- #
#
# ---------------------------------------------------------------------------- #
    if [ ${VERBOSE} = "Y" ];then
       echo "MMO:"$MMO
       echo "CPUS:"$CPUS
       echo "GPU:"$GPU
       echo $CPUS_ENTERED=1; 
       echo "JOB Options:" $JOB_OPTIONS
    fi
# ---------------------------------------------------------------------------- #
    } # Match { after if 'optistruct' check for user in 'optistruct' group  
# ---------------------------------------------------------------------------- #
# Check for a future date entry
# ---------------------------------------------------------------------------- #
[[ ${ASK_DATE} && ! $BSUBDATE ]] && {
	f_ask_date
}
fi # [[ "$CAE_APP" = "optistruct" ]]
#
# ---------------------------------------------------------------------------- #
# StarCCM+ application                                                         #
# ---------------------------------------------------------------------------- #
if [[ "$CAE_APP" = "starccm" ]]
then
    echo $(id -Gn $UID )| grep starccm> /dev/null && {
        VERBOSE="Y"
    
        QUEUE="q64"
    
        VALID_APP="Y"
# ---------------------------------------------------------------------------- #
# Check if multiple STARCCM versions are configured and prompt the user if so. #
# ---------------------------------------------------------------------------- #
        STARCCM_VER=${STARCCM_VERS[0]}

        aprime=();bprime=()

        aprime=(${STARCCM_VERS[@]})
        bprime=("${STARCCM_VERSA[@]}")

        f_get_menu_response "Please chose StarCCM version " STARCCM_VER
    
        aprime=();bprime=()
        aprime=( lsfchoice hwul2 )
        bprime=();let i=0;let k=$(echo ${#STARCCM_Cluster[@]})
    
        while [[ $i -lt $k ]];do bprime[$i]="$STARCCM_VER ${STARCCM_Cluster[$i]}"; ((i++)); done

        f_get_menu_response "Please chose Cluster " HOST

        if [ ${VERBOSE} = "Y" ];then
            echo "StartCCM Version:" $STARCCM_VER
            echo "aprime:" ${aprime[@]} ":" ${#aprime[@]}
            echo "bprime:"${bprime[@]} ":" #{#bprime[@}}
            echo "Cluster Host:" ${HOST}
        fi
#
# ---------------------------------------------------------------------------- #
# Copy the arrays for the Altair CPU options over the WHQ defaults             #
# ---------------------------------------------------------------------------- #
        [[ "${HOST}" = "hwul2" ]] && {
	    STARCCM_CPUS=(${STARCCM_CPUS_Altair[@]})
	    STARCCM_CPUSnum=(${STARCCM_CPUSnum_Altair[@]})
	    STARCCM_CPUSA=("${STARCCM_CPUSA_Altair[@]}") 
        }
# ---------------------------------------------------------------------------- #
# create a simplified version of the configuration for cpus etc, etc...        #
# ---------------------------------------------------------------------------- #
        x=();y=();z=();cpus=()
#
        let k=$(echo ${#STARCCM_CPUS[@]})
        let j=0;i=0
        while [[ ${i} -lt ${k} ]]  
        do
	    [[ ${STARCCM_CPUS[$i]} = 'Y' ]] && {
	        y[$j]=${STARCCM_CPUSA[$i]} 
		cpus[$j]=${STARCCM_CPUSnum[$i]}
		((j++))
            } 
            ((i++))
        done

        CPUS=""

        aprime=(${cpus[@]}) 
        bprime=("${y[@]}") 

        while [ "$CPUS" = "" ] ;
        do
            f_get_menu_response "Enter the number of processors to use" CPUS
        done # while [ "$CPUS= "" ] ;

        QUEUE="q64"
    }

[[ ${ASK_DATE} && ! $BSUBDATE ]] && {
	f_ask_date
}

fi # if [[ "$CAE_APP" = "starccm"  ]]

# ---------------------------------------------------------------------------- #
# MAGMA application                                                            #
# ---------------------------------------------------------------------------- #
#
if [[ "$CAE_APP" = "magma" ]]
then
    echo $(id -Gn $UID )| grep magma> /dev/null && {
	VALID_APP="Y"
	VERBOSE="Y"
# ---------------------------------------------------------------------------- #
# Check if multiple MAGMA versions are configured and prompt the user if so.   #
# ---------------------------------------------------------------------------- #

        MAGMA5_VER=${MAGMA_VERS[0]}

        HOST=""

        aprime=(${MAGMA_VERS[@]})
        bprime=("${MAGMA_VERSA[@]}")
        f_get_menu_response "Please chose MAGMA version option" MAGMA5_VER

        if [ ${VERBOSE} = "Y" ];then
            echo "HOST:"$HOST
            echo "MAGMA5_VER:" ${MAGMA5_VER}
        fi

	CAE_MAGMA_OPT=""
	HOST="lsfchoice"
	aprime=( start restart )
	bprime=( "Start a normal Magma job" "Restart a previous Magma job that was dumped/stopped" )

	f_get_menu_response "Please enter your choice" CAE_MAGMA_OPT

	if [ ${VERBOSE} = "Y" ];then
	    echo "HOST:"$HOST
	    echo "MAGMA Job Option:" ${CAE_MAGMA_OPT}
	fi
    
# ---------------------------------------------------------------------------- #
# align the menu for approved applications only                                #
# ---------------------------------------------------------------------------- #
#
    x=();y=();cpus=();que=()
    let j=0;let i=0;let k=${#MAGMA_CPUS[@]}
#   Make is more flexible by counting the CPU options array 
    while [[ ${i} -lt ${k} ]];do
        if [[ ${MAGMA_CPUS[$i]} = 'Y' ]] ; then 
		x[$j]=${MAGMA_CPUS[$i]}  
		y[$j]=${MAGMA_CPUSA[$i]} 
		cpus[$j]=${MAGMA_CPUSnum[$i]}
		que[$j]=${MAGMA_CPUSque[$i]}
		((j++))
	fi; 
	((i++))
    done

    DEF_CPU=16

    let LOOPCOUNT=0
    CPUS=${cpus[0]}
#    CPUS=${cpus[0]}
    QUEUE=${que[0]}

    while [[ "$CPUS" = "" || ${#cpus[@]} != 1  ]] ;
    do
cat << EOC

Enter the number of processors to use:

EOC

    let k=$(echo ${#x[@]})
    let i=0;j=0
    let i=1;j=0

    while [[ ${j} -lt ${k} ]]  
    do
    echo "    ${i}.  ${y[$j]}" 
    ((j++));((i++))
    done

cat << EOC
    q.  Quit
EOC

echo Please enter your choice :
    read N3
    if [ "$N3" = "" ]; then
        N3=$DEF_CPU
    fi
    let Nx=$N3-1

    case $N3 in

#    1|2|3|4|5|6|7|8|9)	
    [0-9] )
	if [[ ${Nx} -lt ${k} ]] ; then 
	    CPUS=${cpus[${Nx}]}
	    QUEUE=${que[${Nx}]}
	else
	    echo "invalid_choice_msg"
	fi
	;;
    q)	exit 0
	;;
    *)	check_loop_count
	;;
    esac

    done # while [ "$CPUS" = "" ];

    }
fi # if [ "$CAE_APP" = "magma" ]

###
# ---------------------------------------------------------------------------- #
# NASTRAN application                                                          #
# ---------------------------------------------------------------------------- #
###
if [[ "$CAE_APP" = "nxnastran" ]]
then
    VALID_APP="Y"
# ---------------------------------------------------------------------------- #
# Check if multiple NASTRAN versions are configured and prompt the user if so. #
# ---------------------------------------------------------------------------- #

    NXNAST_VER=${NXNAST_VERS[0]}

    HOST="nxnast"

    aprime=(${NXNAST_VERS[@]})
    bprime=("${NXNAST_VERSA[@]}")
    f_get_menu_response "Please chose Nastran version option" NXNAST_VER

    if [ ${VERBOSE} = "Y" ];then
        echo "HOST:"$HOST
        echo "NXNASTRAN_VER:" ${NXNAST_VER}
    fi

[[ ${ASK_DATE} && ! $BSUBDATE ]] && {
	f_ask_date
}

fi # if [ "$CAE_APP" = "nxnastran" ]


# ---------------------------------------------------------------------------- #
# ABAQUS SOLVE (standard, explicit, etc)                                       #
# ---------------------------------------------------------------------------- #
#
if [[ "$CAE_APP" = "abaq" ]]
then
    VALID_APP="Y"
#
# ---------------------------------------------------------------------------- #
# sed code. Will print anything after {$i}= that you pipe in. I can use this   #
# for aaa=123 type options.                                                    #
# for 'gpu' echo "gpu=Y" | sed -n 's/.*'gpu'=//p' | tr '[:lower:]' '[:upper:]  #
# ---------------------------------------------------------------------------- #
    if [ ${VERBOSE} = "Y" ];then
        echo "JOB OPTIONS:" ${JOB_OPTIONS}
    fi
    GPU_ENTERED=false
    for i in user globalmodel oldjob gpu double ;do
        INCNAME=$( echo $JOB_OPTIONS | sed -n 's/.*'$i'=//p' | awk '{print $1}')
        if [ -n "${INCNAME}" ];then
            case ${i} in
		user)
		FORTRAN="Y"; INPUT2=${INCNAME}
		;;
		globalmodel)
		SUBMODEL="Y"; INPUT3=${INCNAME}
		;;
		oldjob)
		OLDJOB="E"; INPUT4=${INCNAME}
		;;
		gpu)
		GPU=$(echo $JOB_OPTIONS | sed -n 's/.*'$i'=//p' | awk '{print $1}' | tr '[:lower:]' '[:upper:]' )
		GPU_ENTERED=true
		echo "gpu option is:" $GPU
		;;
		double)
		PRECISION=$(echo $JOB_OPTIONS | sed -n 's/.*'$i'=//p' | awk '{print $1}' )
		echo "precision option is:" $PRECISION
		;;
		*)
		continue
		;;
	   esac
	fi
    done # for i in user globalmodel oldjob gpu double #

# ---------------------------------------------------------------------------- #
# Set up some default values.                                                  #
# This will identify if the user supplied some of these values , or if they    #
# need to be prompted for them. S.McKenna 2018/11/06                           #
# ---------------------------------------------------------------------------- #
#
    ABAQUS_VER="abq6142"
    FESAFE_EXE="N"
    HOST="lsfchoice"
    [[ -z ${QUEUE} ]] && QUEUE="q2"

    [[ -z ${FORTRAN} ]] && FORTRAN="N"

    [[ -z ${OLDJOB} ]] && OLDJOB="N" 

    [[ -z ${SUBMODEL} ]] && SUBMODEL="N" 

    [[ -z ${PARALLEL} ]] && PARALLEL="domain" 

    [[ -z ${CPUS} ]] && CPUS=""
    
    [[ -z ${GPU} ]] && GPU="N"
    
    [[ -z ${PRECISION} ]] && PRECISION="N"

    let LOOPCOUNT=0
# ---------------------------------------------------------------------------- #
# WHQ Servers                                                                  #
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# align the menu for approved applications only                                #
# ---------------------------------------------------------------------------- #
#
    x=();y=();cpus=();que=();mhost=();fort=();sub=();oldjob=();gpus=()
    let j=0;let i=0;let k=${#ABAQ_CPUS[@]}
#   Make is more flexible by counting the CPU options array 
    while [[ ${i} -lt ${k} ]];do
        if [[ ${ABAQ_CPUS[$i]} = 'Y' ]] ; then 
		x[$j]=${ABAQ_CPUS[$i]}  
		y[$j]=${ABAQ_CPUSA[$i]} 
		cpus[$j]=${ABAQ_CPUSnum[$i]}
		que[$j]=${ABAQ_CPUSque[$i]}
		gpus[$j]=${ABAQ_GPU[$i]}
		mhost[$j]=${ABAQ_CPUShost[$i]}
		fort[$j]=${ABAQ_FORTRAN[$i]}
		sub[$j]=${ABAQ_SUBMODEL[$i]}
		oldjob[$j]=${ABAQ_OLDJOB[$i]}
		precision[$j]=${ABAQ_PRECISION[$i]}
		((j++))
	fi; 
	((i++))
    done

    DEF_CPU=16

    let LOOPCOUNT=0

    while [ "$CPUS" = "" ];
    do
cat << EOC

Enter the number of processors to use:

EOC

    let k=$(echo ${#x[@]})
    let i=0;j=0
    let i=1;j=0

    while [[ ${j} -lt ${k} ]]  
    do
    echo "    ${i}.  ${y[$j]}" 
    ((j++));((i++))
    done

cat << EOC
    q.  Quit
EOC

echo Please enter your choice :
    read N3
    if [ "$N3" = "" ]; then
        N3=$DEF_CPU
    fi
    let Nx=$N3-1

    case $N3 in

    1|2|3|4|5|6|7|8|9|10|11|12)
	if [[ ${Nx} -lt ${k} ]] ; then 
	    CPUS=${cpus[${Nx}]}
	    QUEUE=${que[${Nx}]}
#	    if [[ ${QUEUE} = "q16" && ${CLUSTER} = "AAM_WHQ_cluster1" ]];then
#		echo $(id -Gn $UID )| grep virtual > /dev/null  && { QUEUE=q16virt ; } 
#	    fi
	    [[ ${GPU} = "N" ]] && { GPU=${gpus[${Nx}]};}
	    HOST=${mhost[${Nx}]}
	    [[ ${FORTRAN} = "N" ]] && { FORTRAN=${fort[${Nx}]};}
	    [[ ${SUBMODEL} = "N" ]] && { SUBMODEL=${sub[${Nx}]};}
	    [[ ${OLDJOB} = "N" ]] && { OLDJOB=${oldjob[${Nx}]};}
	    [[ ${PRECISION} = "N" ]] && { PRECISION=${precision[${Nx}]};}
	    
	    if [ ${VERBOSE} = "Y" ];then
	        echo "You picked:${CPUS} CPUS for queue:${QUEUE} with FORTRAN:${FORTRAN} OLD JOB:${OLDJOB} and perhaps SUBMODEL:{$SUBMODEL} or GPUs=${GPU} on HOST:${HOST}"
	    fi
	else
	    echo "invalid_choice_msg"
	fi
	;;
    q)	exit 0
	;;
    *)	check_loop_count
	;;
    esac

    done # while [ "$CPUS" = "" ];
# ---------------------------------------------------------------------------- #
# check for FORTRAN ROUTINES                                                   #
# ---------------------------------------------------------------------------- #
#    N2=""
#    [[ ! -z $FORTRAN ]] && FORTRAN="P"

    aprime=( Y N )
    bprime=( Yes No )

    while [ "$FORTRAN" = "P" ] ;
    do
        f_get_menu_response "Please chose if you want to include a FORTRAN file in your job"  FORTRAN 
    done # while [ "$FORTRAN= "" ] ;

    if [ ${VERBOSE} = "Y" ];then
        echo "Fortran:" ${FORTRAN}
    fi
# ---------------------------------------------------------------------------- #
# check for user requested GPU solve                                           #
# ---------------------------------------------------------------------------- #
    while [ "$GPU" = "P" ] ;
    do
        f_get_menu_response "Please chose if you want to use a GPU to solve in your job"  GPU 
    done # while [ "$GPU= "" ] ;

    if [ ${VERBOSE} = "Y" ];then
        echo "gpus requested:" ${GPU}
    fi
# ---------------------------------------------------------------------------- #
# check for OLDJOB Restart files                                               #
# ---------------------------------------------------------------------------- #
    while [ "$OLDJOB" = "P" ] ;
    do
        f_get_menu_response "Please chose if you want to include an OLDJOB file in your job"  OLDJOB 
    done # while [ "$OLDJOB= "" ] ;

    if [ ${VERBOSE} = "Y" ];then
        echo "OLDJOB:" ${OLDJOB}
    fi
# ---------------------------------------------------------------------------- #
# check for SUB MODEL Global files                                             #
# ---------------------------------------------------------------------------- #
    [[ -z $SUBMODEL ]] && SUBMODEL=""

    aprime=( Y N )
    bprime=( Yes No )

    while [ "$SUBMODEL" = "" ] ;
    do
        f_get_menu_response "Please chose if you want to include a SUBMODEL file in your job"  SUBMODEL
    done # while [ "$SUBMODEL= "" ] ;

    if [ ${VERBOSE} = "Y" ];then
        echo "SubModel:" ${SUBMODEL}
    fi
# ---------------------------------------------------------------------------- #
# check for OLD JOB request (use the old 'aprime/bprime' above for yes/no      #
# ---------------------------------------------------------------------------- #
    [[ -z "$OLDJOB" ]] && OLDJOB=""

    while [ "$OLDJOB" = "" ] ;
    do
        f_get_menu_response "Please choose if you want to include an Old Job file in your job" OLDJOB
    done # while [ "$OLDJOB= "" ] ;

    if [ ${VERBOSE} = "Y" ];then
        echo "OLD Job:" ${OLDJOB}
    fi
# ---------------------------------------------------------------------------- #
# check for Model Validation or Small (<= 2hour) job                           #
# ---------------------------------------------------------------------------- #
    [[ -z "$MODTEST" ]] && MODTEST="" 

    [[ ! $CPUS = "4" ]] && MODTEST="N" 

    while [ "$MODTEST" = "" ] ;
    do
	HOST="twin_dual"
	aprime=( q2mx q2 )
	bprime=( "Model Validation" "Small job <= 2 hours"  )

	f_get_menu_response "Please chose model validation or small job" MODTEST

	[[ ! -z $MODTEST ]] && {
	    QUEUE=${MODTEST}
	    MODTEST="Y"
	}

    done # while [ "$MODTEST" = "" ] ;
# ---------------------------------------------------------------------------- #
# check for Virtualization queue or Normal queue job                           #
# ---------------------------------------------------------------------------- #
#    chkQUEUE=""
#
#    while [[ "$chkQUEUE" = "" &&  ${QUEUE} = "q16virt" ]] ;
#    do
#        aprime=( q16virt q16 )
#        bprime=( "Submit to Virtualization servers" "Submit to other compute servers "  )
#
#        f_get_menu_response "Please chose Servers to run  job" chkQUEUE
#
#        [[ ! -z $chkQUEUE ]] && QUEUE=${chkQUEUE}
#
#    done # while [ "$chkQUEUE" = "" ] ;
# ---------------------------------------------------------------------------- #
# check for Domain or Parallel loop job                                        #
# ---------------------------------------------------------------------------- #
    [[ -z ${PARALLEL} ]] && PARALLEL=""

    while [ "$PARALLEL" = "" ] ;
    do
        aprime=( domain loop )
        bprime=( "Domain {Default}" "Loop"  )

        f_get_menu_response "Please choose Parallelization" PARALLEL
    done

    if [[ ${PARALLEL} = "loop"  ]];then
        PARALLEL="-p parallel="${PARALLEL}
    else
        PARALLEL=""
    fi
# ---------------------------------------------------------------------------- #
# check for Precision options                                                  #
# [double={explicit | both | off | constraint}]                                # 
# ---------------------------------------------------------------------------- #
    [[ -z ${PRECISION} && PRECISION="" ]] && {

	PRECISION="P"

        while [ "$PRECISION" = "P" ] ;
        do
            aprime=( explicit both off constraint )
            bprime=( "Explicit" "Both" "Off" "Constraint" )

            f_get_menu_response "Please choose Precision" PRECISION
        done

        PRECISION="-j double="${PRECISION}
    }
# ---------------------------------------------------------------------------- #
# CHECK for user entered dates                                                 #
# ---------------------------------------------------------------------------- #
LOOPCOUNT=0

[[ ${ASK_DATE} && ! $BSUBDATE ]] && {
	f_ask_date
}
# 

fi  # if [ "$CAE_APP" = "abaq" ]

# ---------------------------------------------------------------------------- #
# ABAQUS SYNTAX check                                                          #
# ---------------------------------------------------------------------------- #
if [[ "${CAE_APP}" = "abaqck" ]] 
then
    VALID_APP="Y"

    ABAQUS_VER="abq6142"
    aprime=(${ABAQUS_VERS[@]})
    bprime=("${ABAQUS_VERSA[@]}")
    f_get_menu_response "Please chose ABAQUS version option" ABAQUS_VER

    if [[ ${VERBOSE} = "Y" ]];then
        echo "ABAQUS Version:" ${ABAQUS_VER}
    fi
fi # if [ "$CAE_APP" = "abaqck" ]

if [ "${CAE_APP}" = "magma5" ]
then
    VALID_APP="Y"
fi

if [ "${CAE_APP}" = "adams" ]
then
    VALID_APP="Y"
fi
# ---------------------------------------------------------------------------- #
# No valid application was found, selected , or input                          #
# ---------------------------------------------------------------------------- #
if [ ${VALID_APP} = "N" ];then
	echo "You entered an application that has not been setup for this site..."
	echo "or you do not have authorization to run the application selected"
	exit 1
fi
# ---------------------------------------------------------------------------- #
# Now the application has been verified, check the INPUT file and all the      #
# input files for ABAQUS,NASTRAN, Optistruct, STARCCM and the directories      #
# for MAGMA, etc.                                                              #
# ---------------------------------------------------------------------------- #

[[ -z $INPUT ]] && INPUT=""

let LOOPCOUNT=0
while [ "$INPUT" = "" ] ;
do
    if [ ${CAE_APP} = "magma" ]
    then
        echo " "
        echo "Select one of the following folders or key in a complete folder specification..."
        ls -1 2> /dev/null | awk '{print "     "$0}'
        echo " "
        echo $BOL Please enter Input folder:$EOL
        read INPUT

        [[ ! -d $INPUT ]] && {
                ((LOOPCOUNT++))
                if [ $LOOPCOUNT -eq 3 ]
                then
                        echo "You have exceeded the retry limit..."
                        echo "The script is exiting"
                        echo "To submit a job, restart the script."
                        exit 1
                else
                        echo "$INPUT does not exist in current directory."
                        echo "Enter a valid folder name."
                        INPUT=""
                fi
        }
    else
	echo " "
        if [[ -z $INPUT ]];then
            INPUT=""
#        FILE_SEARCH="*.f"
            f_get_input_file "Input file:" INPUT
        fi
    fi # [ ${CAE_APP} = "magma" ]

done # while [ "$INPUT" = "" ] ;
# 
# ---------------------------------------------------------------------------- #
# CHECK for GPU usage request                                                  #
# ---------------------------------------------------------------------------- #
#if [ "${GPU}" = "Y" ];then
#    [[ ! ${GPU_ENTERED} ]] && {
#        if [[ ! -z ${JOB_OPTIONS} ]];then  JOB_OPTIONS=${JOB_OPTIONS}" -j gpu=Y"
#        else
#           JOB_OPTIONS=" -j gpu=Y"
#        fi
#    }
#fi # if [ ${GPU} = "Y" ]
# ---------------------------------------------------------------------------- #
# CHECK for GPU usage request                                                  #
# ---------------------------------------------------------------------------- #
if [ "${GPU}" = "Y" ];then
        if [[ ! -z ${JOB_OPTIONS} ]];then  

	   [[ $(echo  "${JOB_OPTIONS}" | grep 'gpu=') ]] || { 
		echo "gpu missing - add it"
		JOB_OPTIONS=${JOB_OPTIONS}" -j gpu="${GPU}
		}
        else
           JOB_OPTIONS=" -j gpu="${GPU}
        fi
fi # if [ ${GPU} = "Y" ]
# ---------------------------------------------------------------------------- #

# ---------------------------------------------------------------------------- #
# CHECK for FORTRAN subroutine files                                           #
# ---------------------------------------------------------------------------- #
if [ "${FORTRAN}" = "Y" ];then
    if [[ -z $INPUT2 ]];then
        INPUT2=""
        FILE_SEARCH="*.f"
        f_get_input_file "FORTRAN subroutine file:" INPUT2

        if [[ ! -z ${JOB_OPTIONS} ]];then  JOB_OPTIONS=${JOB_OPTIONS}" -j user="${INPUT2}
        else
           JOB_OPTIONS=" -j user="${INPUT2}
        fi
    fi
fi # if [ ${FORTRAN} = "Y" ]
# ---------------------------------------------------------------------------- #
# CHECK for SUBMODEL GLOBAL files                                              #
# ---------------------------------------------------------------------------- #
if [ "${SUBMODEL}" = "Y" ];then
    if [[ -z ${INPUT3} ]]; then # INPUT3 was passed in somehow... :)
        INPUT3=""

        FILE_SEARCH="*.odb"

        f_get_input_file "Global submodel file:" INPUT3

        if [[ ! -z ${JOB_OPTIONS} ]];then  JOB_OPTIONS=${JOB_OPTIONS}" -j globalmodel="${INPUT3}
        else
           JOB_OPTIONS=" -j globalmodel="${INPUT3}
        fi
    fi
fi # if [ ${SUBMODEL} = "Y" ]

# ---------------------------------------------------------------------------- #
# CHECK for Old Job files                                                      #
# ---------------------------------------------------------------------------- #
if [ "${OLDJOB}" = "Y" -o "${OLDJOB}" = "E" ];then
    OLDJOB_NAME=$(echo $INPUT4 | awk -F. '{print $1}')
fi
#
if [ "${OLDJOB}" = "Y" ];then
    if [[ -z ${INPUT4} ]]; then # INPUT4 was not passed in :)
        INPUT4=""
        FILE_SEARCH="*.odb"
        f_get_input_file "Old job ODB file name:" INPUT4
        OLDJOB_NAME=$(echo $INPUT4 | awk -F. '{print $1}')
    fi
    if [[ ! -z ${JOB_OPTIONS} ]];then  JOB_OPTIONS=${JOB_OPTIONS}" -j oldjob="${OLDJOB_NAME}
    else
       JOB_OPTIONS=" -j oldjob="${OLDJOB_NAME}
    fi
fi # if [ ${OLDJOB} = "Y" ]

if [[ ! -z ${INPUT4} ]] ;then
    if [[ ! -f ${INPUT4} ]] ;then
        echo "OldJob file name:"${INPUT4} ":invalid file name"
        exit 24
    fi
fi
#  
#  If OLDJOB="E" then this was passed in via the command line. Strip out any trailing ".odb"
#  
if [ "${OLDJOB}" = "E" ];then
    JOB_OPTIONS=$(echo "${JOB_OPTIONS}" | sed -e "s!$INPUT4!$OLDJOB_NAME!" )
fi # if [ ${OLDJOB} = "E" ]

# ---------------------------------------------------------------------------- #
# CHECK create the script and submit the job                                   #
# ---------------------------------------------------------------------------- #

OLDODB=""
let LOOPCOUNT=0
#JOB_OPTIONS=""
FILE_SEARCH="*.odb"
SUBMODEL=0
# ---------------------------------------------------------------------- #
# commented out for now. superceded by code above, but this may come     #
# back.                                                                  #
# ---------------------------------------------------------------------- #
#if [ "$CAE_APP" = "abaq" ]
#then
#        SUBMODEL=`grep -i submodel $INPUT | wc -l`
#fi
#while [ "$OLDODB" = "" -a $SUBMODEL -gt 0 ] ;
#do
#	echo " "
#	echo "The input deck contains the SUBMODEL parameter."
#	echo "Select one of the following files or key in a complete file specification..."
#        ls -1 ${FILE_SEARCH} 2> /dev/null | awk '{print "     "$0}'
#	echo " "
#        echo $BOL Please enter old results file name:$EOL
#    	read OLDODB
#
#	[[ ! -f $OLDODB ]] && {
#		LOOPCOUNT=$((1 + ${LOOPCOUNT}))
#        	if [ $LOOPCOUNT -eq 3 ]
#        	then
#			exceeded_retry_msg 
#                	exit 1
#        	else
#        		echo "$OLDODB does not exist in current directory."
#			echo "Enter a valid filename."
#			OLDODB=""
#    	   	fi
#	}
#JOB_OPTIONS=${JOB_OPTIONS}" -o ${OLDODB}"
#done # while [ "$OLDODB" = "" -a $SUBMODEL -gt 0 ] ;
# ---------------------------------------------------------------------- #
# commented out for now. superceded by code above, but this may come     #
# back.                                                                  #
# ---------------------------------------------------------------------- #

let LOOPCOUNT=0
FILE_SEARCH="*.odb"
TEMPMODEL=0
if [ "$CAE_APP" = "abaq" ];then
TEMPMODEL=`grep -i temperature $INPUT | grep -i file | wc -l | head -1`
fi
while [ "$OLDODB" = "" -a $TEMPMODEL -gt 0 ] ;
do
    DEF_TEMP_ODB=`grep -i temperature $INPUT | grep -i file | cut -d, -f2 | cut -d= -f2 | head -1`
    echo " "
    echo "The input deck contains the TEMPERATURE parameter."
    echo "The old odb file that will be used for this analysis:$DEF_TEMP_ODB.odb "
    OLDODB=${DEF_TEMP_ODB}.odb	
    JOB_OPTIONS=${JOB_OPTIONS}" -o ${OLDODB}"
done # while [ "$OLDODB" = "" -a $TEMPMODEL -gt 0 ] ;
#
# ---------------------------------------------------------------------------- #
# CHECK create the script and submit the job                                   #
# ---------------------------------------------------------------------------- #
# Submit the job to the proper queueing script now that the parameters are     #
# gathered.                                                                    #
# for PBO->WHQ script. the CAE team wishes that ABAQUS and NASTRAN jobs will   #
# run locally. Optistruct jobs will be submitted to the Altair appliance       #
# at WHQ.                                                                      #
# ---------------------------------------------------------------------------- #
#
case $CAE_APP in

    abaqck)
	/usr/local/bin/abaquscheck2017_v2.1.sh -i $INPUT -v ${ABAQUS_VER}
        exit 0
        ;;

    adams)
	/usr/local/bin/qadams_v1.sh -i $INPUT -v ${ADAMS_VER}
        exit 0
        ;;
    abaq)
	echo $INPUT $QUEUE $CPUS "Job Options:" $JOB_OPTIONS $PARALLEL $ABAQUS_VER $HOST 
	/usr/local/bin/qabaq2.2017_v3.5.sh -i ${INPUT} -q $QUEUE -n $CPUS ${JOB_OPTIONS} ${PARALLEL} -v ${ABAQUS_VER} -m ${HOST}
	exit 0
	;;
    nxnastran)
        echo "/usr/local/bin/qnxnastran1102.3.sh -i "$INPUT" -node "${HOST}" -v "${NXNAST_VER}
	/usr/local/bin/qnxnastran1102.3.sh -i $INPUT -node ${HOST} -v ${NXNAST_VER} ${JOB_OPTIONS}
	exit 0
	;;
    optistruct)
	echo $CAE_APP ":"$INPUT -m ${HOST} -v ${OS_VER} ${JOB_OPTIONS} "CPUS:"${CPUS}
	if [[ "${HOST}" = "hwul2" ]];then
	    /usr/local/bin/qoptistruct_v5.1.sh -i $INPUT -v ${OS_VER}
	else
	    echo $CAE_APP ":"$INPUT -m ${HOST} -v ${OS_VER} ${JOB_OPTIONS} "NCPUS:"${CPUS}
 	    /usr/local/bin/qoptistruct_v1.sh -i $INPUT -v ${OS_VER} ${JOB_OPTIONS} -ncpus ${CPUS}
	fi
	exit 0
	;;
    starccm)
	echo $INPUT -m ${HOST} -n $CPUS -v ${STARCCM_VER} ${JOB_OPTIONS}
	if [[ "${HOST}" = "hwul2" ]];then
	    /usr/local/bin/qstarccmplust_v5.sh -i $INPUT -m ${HOST} -n $CPUS -v ${STARCCM_VER}
	else
	    /usr/local/bin/qstarccmplust_v4.2.6.sh -i $INPUT -m ${HOST} -n $CPUS -v ${STARCCM_VER} ${JOB_OPTIONS}
	fi
	exit 0
	;;
    magma)
	echo $INPUT -m ${HOST} -n $CPUS -v ${MAGMA5_VER}
	/usr/local/bin/magma5_v5.4.1.sh -i ${INPUT} -q $QUEUE -n $CPUS -v ${MAGMA5_VER} -m ${HOST} -r ${CAE_MAGMA_OPT}
	exit 0
	;;
    *)
	echo
	echo Unrecognized problem.
	echo Script is exiting.
	echo Contact IT support.
	echo
	exit 1
	;;
esac
exit

# -------------------------------------------------------------------------------------- #
# Exit - This is the end. Jim Morrison and the Doors...................................  #
# -------------------------------------------------------------------------------------- #

