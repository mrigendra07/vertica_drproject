#!/bin/bash
#######################################################################
# 				HEARTBEAT DAEMON
#----------------------------------------------------------------------
# Author          : Bhupal Rai
# Release version : 1.0.0
# Updated by      : Bhupal Rai
# Last updated    : 2017 AUG 25
#----------------------------------------------------------------------
# Daemon skeleton is based on Linux standard daemon skeleton.
# Should be initiated by drstartup script.
#
# Usage:  heartbeat.sh <config_file>
#
#######################################################################
## < NOtes here >
##
#######################################################################

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_NAME=$(basename $0)
TMP_DIR="${BASE_DIR}/tmp"
DEVNULL="/dev/null"
DEFAULT_SLEEPTIMESEC="15"
SLEEPTIMESEC=${DEFAULT_SLEEPTIMESEC}
CONFIG_FILE=

# personal files
DAEMON_LOG_FILE="${TMP_DIR}/logs/daemon.log"
ENV_INFOFILE="${TMP_DIR}/fordemon/._environmentinfo"
STATUSFILE="._drstatus_file"
STATUSFILE_ABS_F="${TMP_DIR}/${STATUSFILE}"

# output files
STDOUTFILE="${TMP_DIR}/outfile"
STDERRFILE="${TMP_DIR}/errfile"

# other components
CONSTANTS="constants.sh"
STATUS_LOG_HANDLER="status_log_handler.sh"
TRANSFER_REQ_HANDLER="transfer_request_handler.sh"
TRANSFER_INIT_HANDLER="transfer_init_handler.sh"
TRANSFER_PRE_PROCESSOR="transfer_preprocessor.sh"
TRANSFER_ENGINE="transfer_engine.sh"
DATABASE="database.sh"

# export for other components
export BASE_DIR
export TMP_DIR
export STDOUTFILE
export STDERRFILE
export CONSTANTS
export STATUS_LOG_HANDLER
export TRANSFER_REQ_HANDLER
export TRANSFER_INIT_HANDLER
export TRANSFER_PRE_PROCESSOR
export TRANSFER_ENGINE
export STATUSFILE_ABS_F
export DATABASE

# others
# config file keys should exist in global config file
CONFIG_FILE_KEYS=(log_file daemon_sleep_time transfer_status_base parallel_transfer configfile)


#######################################################################
#		daemon skeleton specific
#######################################################################
cd /

if [ "$1" = "child" ] ; then
    umask 0
    ${BASE_DIR}/${SCRIPT_NAME} "drmon" "$@" </dev/null >/dev/null 2>/dev/null &
    exit 0
fi

if [ "$1" != "drmon" ] ; then
    setsid ${BASE_DIR}/${SCRIPT_NAME} "child" "$@" &
    exit 0
fi

# redirect stderr/stdout to error file
exec  >${STDOUTFILE}
exec 2>${STDERRFILE}
exec 0<${DEVNULL}

#######################################################################
# Create required files/folders if doesn't exists
#######################################################################
mkdir -p ${TMP_DIR}
touch ${STATUSFILE_ABS_F}
touch ${DAEMON_LOG_FILE}
touch ${ENV_INFOFILE}
touch ${STDOUTFILE}
touch ${STDERRFILE}
#
# clean junk files/folders if exists from previous run
# < clean all logs,err,stdout, tmp, pid, status, dummy>
cat /dev/null > ${STDOUTFILE}
cat /dev/null > ${STDERRFILE}

#######################################################################
# 			functions
#######################################################################
function validate_file() {
    # ret code:
    # 1=no arg
    # 2=not a file
    # 3=empty
    # 4= not readable

    vf_args=("$@")
    [ ${#vf_args[@]} -ne 1 ] && { return 1; }

    # file must exist, not empty & readable
    TMP_FNAME="${vf_args[0]}"

    [ ! -f "$TMP_FNAME" ] && { return 2; }
    if [ ! -s "$TMP_FNAME" ]; then
    	return 3
    fi

    F_TYPE=$(file ${TMP_FNAME} | cut -d\  -f2)
    [ ${F_TYPE} != "ASCII" ] && { return 4; }

    return 0
}


function read_config (){
	#
	# parameters: config_parameter name
	# returns: config_value value
	#
	config_file=${1}
	config_param=${2}
	[ ! $(validate_file ${1}) = 0 ] && { logger "Error while trying to read configuration file.Please verify \
						 it exists, is readable and not empty.";
					 echo "0"
					 return;
	}
	_tmp_01=$(cat ${config_file} | grep -iw "${config_param}" | head -n 1 | cut -d"=" -f2 )
	#[[ ${_tmp_01} =~ ^-?[0-9]+$ ]] && { echo ${_tmp_01}; return; }
	echo "${_tmp_01}"
	return
}

function log_daemonsmsg (){
	# locking file is not required
	echo "`date '+%Y-%m-%d %H:%M:%S'` ${1}" >> ${DAEMON_LOG_FILE}
}

function update_internal_config_file(){
	########################################################################
	# Update internal configuration file from external configuration file  #
	# if any change is done in external configuration file                 #
	#                                                                      #
	# External configuration file:                                         #
	# 	Configuration file that user edits as per requirement              #
	# Internal configuration file:                                         #
	#	Configuration file that is used only by application.               #
	#	This file have same values corresponding to the external           #
	#	configuration file but the key may be different which only         #
	#	an application may understand                                      #
	########################################################################
	for _key in ${CONFIG_FILE_KEYS[@]}; do
		_cur_val=$( cat ${STATUSFILE_ABS_F} | grep ${_key}|cut -d'=' -f2|head -n1 2>/dev/null)
		_new_val=$( cat ${BASE_DIR}/${CONFIG_FILE} | grep ${_key}|cut -d'=' -f2|head -n1 2>/dev/null)
		_new_line="${_key}=${_new_val}"
		#
		# if key doesn't exists, add
		[ $(cat ${STATUSFILE_ABS_F}|grep ${_key}|wc -l) -eq 0 ] && \
			{ echo "${_new_line}" >> ${STATUSFILE_ABS_F}; continue; }
		#
		# if configuration file is updated, update internal configuration file
		if [ "${_cur_val}" != "${_new_val}" ]; then
			# value is updated
			sed -i '/^#/!s|.*'"${_key}"'.*|'"${_new_line}"'|g' ${STATUSFILE_ABS_F} \
				2> >(gawk $'{print strftime("%F %T", systime())" [daemon] error while updating key:value '${_key}:${_new_val}'", $0}' >&2)  >>${DAEMON_LOG_FILE}
		fi
	done
}

function archive_oldfiles(){
	#
	# Archive all .ini, .sts, .req, .log files older than 7 days
	#
	return 0
}
#######################################################################
# 			EOF functions
#######################################################################

# validate
CONFIG_FILE=${3}
EX_MODE=
if [ "${4}" = "debug" ]; then
	EX_MODE="-x"
	export EX_MODE
fi
#ret_code=$(validate_file ${CONFIG_FILE})
#if [ ! ${ret_code} = 0 ]; then
#    logger "configuration file validation failedRequests. Please verify \
#    	    it exists, is readable and not empty."
#    exit 1
#fi

#
# daemon loop
#
logger "dr replication daemon started successfully"
logger "logging module initialized"

############################################ debug code ###############################################################
echo  "cur dir                :"`pwd`                     > /tmp/drsetup.txt
echo  "BASE_DIR               :"$BASE_DIR                >> /tmp/drsetup.txt
echo  "SCRIPT_NAME            :"$SCRIPT_NAME             >> /tmp/drsetup.txt
echo  "TMP_DIR                :"$TMP_DIR                 >> /tmp/drsetup.txt
echo  "DEVNULL                :"$DEVNULL                 >> /tmp/drsetup.txt
echo  "DEFAULT_SLEEPTIMESEC   :"$DEFAULT_SLEEPTIMESEC    >> /tmp/drsetup.txt
echo  "SLEEPTIMESEC           :"$SLEEPTIMESEC            >> /tmp/drsetup.txt
echo  "CONFIG_FILE            :"$CONFIG_FILE             >> /tmp/drsetup.txt
echo  "DAEMON_LOG_FILE        :"$DAEMON_LOG_FILE         >> /tmp/drsetup.txt
echo  "ENV_INFOFILE           :"$ENV_INFOFILE            >> /tmp/drsetup.txt
echo  "STATUSFILE             :"$STATUSFILE              >> /tmp/drsetup.txt
echo  "STATUSFILE_ABS_F       :"$STATUSFILE_ABS_F        >> /tmp/drsetup.txt
echo  "STDOUTFILE             :"$STDOUTFILE              >> /tmp/drsetup.txt
echo  "STDERRFILE             :"$STDERRFILE              >> /tmp/drsetup.txt
echo  "CONSTANTS              :"$CONSTANTS               >> /tmp/drsetup.txt
echo  "STATUS_LOG_HANDLER     :"$STATUS_LOG_HANDLER      >> /tmp/drsetup.txt
echo  "TRANSFER_REQ_HANDLER   :"$TRANSFER_REQ_HANDLER    >> /tmp/drsetup.txt
echo  "TRANSFER_INIT_HANDLER  :"$TRANSFER_INIT_HANDLER   >> /tmp/drsetup.txt
echo  "TRANSFER_PRE_PROCESSOR :"$TRANSFER_PRE_PROCESSOR  >> /tmp/drsetup.txt
echo  "TRANSFER_ENGINE        :"$TRANSFER_ENGINE         >> /tmp/drsetup.txt
echo  "CONFIG_FILE_KEYS       :"${CONFIG_FILE_KEYS[@]}   >> /tmp/drsetup.txt
echo  "CONFIG_FILE            :"$CONFIG_FILE             >> /tmp/drsetup.txt
echo  "EX_MODE                :"$EX_MODE                 >> /tmp/drsetup.txt
#exit 0
######################################### eof debug code ##############################################################

while true; do
	#
	# Daemon components execution here
	#
	# Note: Any change in configuration file will be reflected to new transfers only.
	#       Daemon will update the change to file ${STATUSFILE} in ${TMP_DIR} directory.
	
	#
	# update status file from global logfile
	update_internal_config_file
	#
	# we execute components here
	/bin/bash ${EX_MODE} ${BASE_DIR}/${TRANSFER_REQ_HANDLER}
	/bin/bash ${EX_MODE} ${BASE_DIR}/${TRANSFER_INIT_HANDLER}
	#
	# archive old files
	archive_oldfiles
	#
	# read sleep time
	SLEEPTIMESEC=$(read_config "${BASE_DIR}/${CONFIG_FILE}" "daemon_sleep_time")
	if ! [[ ${SLEEPTIMESEC} =~ ^-?[0-9]+$ ]] || [ ${SLEEPTIMESEC} -lt 15 ]; then
		SLEEPTIMESEC=${DEFAULT_SLEEPTIMESEC}
	fi
	sleep ${SLEEPTIMESEC}
done
exit
