#!/bin/bash
#######################################################################
#				Status and Log Handler (SLH)
#----------------------------------------------------------------------
# This component maintains status files, logs, maintains log.
# Contains all helper modules required by other components.
#
#######################################################################

source ${BASE_DIR}/constants.sh

function is_string(){
	echo "true"
}

function is_number(){
	#
	# Check if parameter passed is number
	# rtype: true or false
	value=${1}
	if [[ ${value} =~ ^-?[0-9]+$ ]]; then
		echo "${TRUE_STR}"
	else
		echo "${FALSE_STR}"
	fi
	exit 0
}

function log(){
	#
	# Logging module.
	# Write to global log file if logfile absolute path is not provided.
	#
	# parameters: log message, logfile (optional)
	# log format: timestamp [<component_name>] <log message>
	#

	# component writing the log
	cmpnt=${1}
	# message
	logmsg=${2}
	#
	# if logfile not passed, write to global log provided in config_file
	if [ -z "${3}" ]; then
		#config_file=$(cat ${STATUSFILE_ABS_F} | grep "${configfile_str}" | cut -d '=' -f2 | head -n 1 )
		config_file="${STATUSFILE_ABS_F}"
		[ ! -f ${config_file} ] &&\
		{ echo `date '+%Y-%m-%d %H:%M:%S'`" [status_log_handler.sh] configfile '${config_file}' is not a regular file" >>${STDERRFILE} ; }

		logfile=$( cat ${STATUSFILE_ABS_F} | grep "${logfile_str}" | cut -d '=' -f2 | head -n 1)
		touch ${logfile}
		[ ! -f ${logfile} ] &&\
		{ echo `date '+%Y-%m-%d %H:%M:%S'`" [status_log_handler.sh] logfile '${logfile}' is not a regular file" >>${STDERRFILE};\
		  echo `date '+%Y-%m-%d %H:%M:%S'`" [status_log_handler.sh] logging: ${logmsg}" >>${STDERRFILE};
		  return;
		}
	# else, write to file
	else
		logfile=${3}
	fi
    echo `date '+%Y-%m-%d %H:%M:%S'`" [${cmpnt}] ${logmsg}" >> ${logfile}
}


#function read_config (){
#	#
#	# parameters: config_file config_parameter_name
#	# returns: config_value value
#	#
#	config_file=${1}
#	config_param=${2}
#	[ ! $(validate_file ${1}) = 0 ] && { log "SLH" "Error while trying to read configuration file.Please verify \
#						 it exists, is readable and not empty.";
#					 echo ""
#					 return;
#	}
#	_tmp_01=$(cat ${config_file} | grep -iw "${config_param}" | head -n 1 | cut -d"=" -f2 )
#	echo "${_tmp_01}"
#	return
#}


function validate(){
	echo "validate"
}

function check_vbr(){
	hash ${VBRPY} 2> /dev/null
	if [ "$?" = "0" ]; then
			echo "1";
	else
			echo "0";
	fi
}

function job_maxRetry_reached(){
	#
	# if job's retry limit exceeded then return 0 else 1
	#
	_job="${1}"
	retries=$(cat ${JOB_RETRY_ABS_F} | grep "${_job}" | cut -d':' -f2)
	## if empty
	#[ -z "${retries}" ] && { return 0; }
	if [ ${retries} -lt ${JOBS_MAX_RETRYLIMIT} ]; then
		return 0
	else
		return 1
	fi
}

function update_transferSTS(){
	_job=${1}
	_status=${2}
	cur_request_sts_abs_f="${JS_ABS_DIR}/${_job}.sts"
	echo "${_status}" > ${cur_request_sts_abs_f}
}

function move_tofailq(){
	#
	# Move running job to failedRequests queue when ever failure occurs during transfer
	#
	# we expect request file with absolute path is provided in parameter
	typeset _req_abs_f
	_req_abs_f=${1}
	mv ${_req_abs_f} ${FAILEDREQUESTS_DIR} \
		2> >(gawk $'{print strftime("%F %T", systime())" ['${SLH}:${_job}'] Error while rejecting job.", $0}' >&2)  >>${STDERRFILE}
}

function reject_job(){
	#
	# Move job to rejectedRequests queue
	#
	typeset _req_abs_f
	_req_abs_f=${1}
	mv ${_req_abs_f} ${REJECTEDREQUESTS_DIR} \
		2> >(gawk $'{print strftime("%F %T", systime())" ['${SLH}:${_job}'] Error while rejecting job.", $0}' >&2)  >>${STDERRFILE}
}

function incrementRetryCnt(){
	#
	# Increase retry count
	#
	_job="${1}"
	retries=$(cat ${JOB_RETRY_ABS_F} | grep "${_job}" | cut -d':' -f2)
	if [ -z "${retries}" ]; then
		echo "${_job}:1" >>${JOB_RETRY_ABS_F}
	else
		retries=$[retries+1]
		sed -i '/^#/!s|'"${_job}"'.*|'"${_job}:${retries}"'|g' ${JOB_RETRY_ABS_F}
	fi
}

function updateEngine_LF(){
	#
	# add/remove transfer engine locks
	#
	_job=${1}
	action=${2}
	if [ ${ENGN_LOCKACTION_ADD_STR} = ${action} ]; then
		touch "${ENGN_LOCK_ABS_DIR}/${_job}.lf"
	elif [ ${ENGN_LOCKACTION_DEL_STR} = ${action} ]; then
		test "${_job}.lf"
		[ $? -eq 0 ] && { rm -f "${ENGN_LOCK_ABS_DIR}/${_job}.lf" 2>&1>/dev/null; }
	fi
}

function create_elig_lockfile(){
	#
	# Creates elig_lockfile
	#

	# we assume file with absolute path
	touch "${TRNS_ELIG_LOCK_ABS_F}" \
		2> >(gawk $'{print strftime("%F %T", systime())" ['${SLH}:'] Error creating lock.", $0}' >&2)  >>${STDERRFILE}
	[ $? -eq 0 ] || return 1
	return 0
}

function rm_elig_lockfile(){
	#
	# Remove elig_lockfile
	#

	# we assume file with absolute path
	[ -z "${TRNS_ELIG_LOCK_ABS_F}" ] && return 1
	rm -f "${TRNS_ELIG_LOCK_ABS_F}" \
		2> >(gawk $'{print strftime("%F %T", systime())" ['${SLH}:'] Error while releasing lock.", $0}' >&2)  >>${STDERRFILE}
	[ $? -eq 0 ] || return 1
	return 0
}

function elig_lockfile_exists(){
	#
	# Check if elig_lockfile exists
	#
	# Return:
	# yes : if exists
	# no : if doesn't exists

	# we assume file with absolute path
	[ -f "${TRNS_ELIG_LOCK_ABS_F}" ] || {
		echo 'no'
		return 1
	}
	echo 'yes'
	return 0
}
