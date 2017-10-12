#!/bin/bash
#######################################################################
#             Transfer Engine
#----------------------------------------------------------------------
# Author          : Bhupal Rai
# Release version : 1.0.0
# Updated by      : Bhupal Rai
# Last updated    : 2017 AUG 25
#----------------------------------------------------------------------
# Responsible for initiating vbr.py tool.
# Monitor transfer
#
# Parameters: job_name, transfer_initiating host name
#######################################################################

source ${BASE_DIR}/status_log_handler.sh
#
# global variables
#
job_name=
job_spcfclog_f=
job_spcfclog_abs_f=
transfer_ini_file_f=
src_transfer_ini_file_abs_f=
dst_transfer_ini_file_abs_f=
vbr_executing_node=

job_spcfc_sts_abs_f=
transfer_init_host=

#######################################################################
# 			functions
#######################################################################
function have_pwdless_ssh(){
	#
	# Verify password less ssh
	#
	# Parameters: host
	# Return:
	# 0 : configured
	# 1 : not-configured
	return 0

}

function run_preengine_task {
	#
	# validate engine input
	#
	params=( "$@" )
	job_name=${params[0]}

	transfer_ini_file_f=$(ls ${ENGN_INPUT_DIR}/${job_name}_*.ini | rev | cut -d'/' -f 1 | rev | head -n 1) \
		2> >(gawk $'{print strftime("%F %T", systime())" ['${TE}:${job_name}'] Error while in getting ini file.", $0}' >&2)  >>${STDERRFILE}
	src_transfer_ini_file_abs_f="${ENGN_INPUT_DIR}/${transfer_ini_file_f}"
	#
	# create job specific log if not initiated
	job_spcfclog_f="${job_name}.log"
	job_spcfclog_abs_f="${JOB_SPCFC_LOG_DIR}/${job_spcfclog_f}"
	touch ${job_spcfclog_abs_f}
	#
	# transfer init host
	transfer_init_host=${params[1]}
	dst_transfer_ini_file_abs_f="${VBRCONFIG_LANDING_BASE}/${job_name}/${transfer_ini_file_f}"
	#
	# verify passwordless ssh configured
	if ! have_pwdless_ssh "${transfer_init_host}"; then
		log "${TE}" "[${job_name}] Password less ssh is not configured in host ${transfer_init_host}." "${job_spcfclog_abs_f}"
		return 1
	fi
	return 0
}

function run_postengine_task(){
	#
	# Perform transfer post task
	# 1. Mail:
	#    - transfer status file
	#    - object validation

	# object validation >> ${mail_body}
	# cat "${mail_body}" | mail -s 'REPLICATION STATUS OF TRANSFER ID ${REQ_ID}" "${mail_chain}"
	return 0
}

function autonomous_engine {
	#
	# This is fully autonomous module which is a core part of transfer engine.
	#
	# Note: Main task is to start dr-replication and monitor progress every 45 seconds
	#
	# parameters:

	log ${TE} "autonomous_engine started" "${job_spcfclog_abs_f}"
	#
	# start vbr transfer
	_r_stdoutfile="${job_name}_trns.sts"
	_r_vbr_pid_f="._${job_name}_trns.pid"
	_err_f="${job_name}_std.err"
	_log_f="${job_name}_transfer.log"
	_cmd_pid_f=".${job_name}_cmd.pid"
	cmd=$(
		cat <<-EOF
    		cd ${VBRCONFIG_LANDING_BASE}/${job_name};
    		(${VBRPY} -t replicate -c ${transfer_ini_file_f} 2> ${_err_f} | tee ${_log_f}) &
    		echo \$! > ${_cmd_pid_f};
    		exit 0;
		EOF
	)
	${SSH} -q ${transfer_init_host} -p 22   ${cmd} &
	#
	# loop until get cmd pid
	while [ -z "${_cmd_pid}" ]; do
		_cmd_pid=$(${SSH} -q ${transfer_init_host} -p 22 "cd ${VBRCONFIG_LANDING_BASE}/${job_name}; \
								cat ${_cmd_pid_f} 2>/dev/null")
	done
	#
	# Get actual pid( vbr pid).
	# -vbr pid $_r_vbr_pid should be child of $_cmd_pid.
	# -wait for 15 seconds to get pid, then leave process
	_r_vbr_pid=
	_dummy_01_abs="${DUMMY_ABS_DIR}/.${job_name}_$(date +'%Y%m%d%H%M%S')"
	{ rm -f ${_dummy_01_abs} 2>${DEVNULL}; sleep 15; touch ${_dummy_01_abs}; } &
	while [ -z "${_r_vbr_pid}" ];do
		_r_vbr_pid=$(${SSH} -q ${transfer_init_host} -p 22 "\
			ps -ef | grep ${VBRPY} | grep ${_cmd_pid} | grep -v 'bash -c' | grep 'replicate -c ${transfer_ini_file_f}' | awk '{print \$2}' \
			")
		#
		# check wait signal
		[ $(ls -a ${_dummy_01_abs} 2>/dev/null |wc -l) -gt 0 ] && {
		 		log ${TE} "[${job_name}] wait time exceeded, leaving vbr process" "${job_spcfclog_abs_f}";  break; }
	done
	#
	# monitor & update
	while true; do
		#
		#
		echo " ------------------"	> /tmp/${_r_stdoutfile}
		echo " Transfer status"		>> /tmp/${_r_stdoutfile}
		echo " ------------------"	>> /tmp/${_r_stdoutfile}
		${SSH} -q ${transfer_init_host} -p 22 "tail ${VBRCONFIG_LANDING_BASE}/${job_name}/${_log_f}" >> /tmp/${_r_stdoutfile}
		echo 						>> /tmp/${_r_stdoutfile}
		echo 						>> /tmp/${_r_stdoutfile}
		echo " ------------------"	>> /tmp/${_r_stdoutfile}
		echo " Errors"				>> /tmp/${_r_stdoutfile}
		echo " ------------------"	>> /tmp/${_r_stdoutfile}
		${SSH} -q ${transfer_init_host} -p 22 "tail ${VBRCONFIG_LANDING_BASE}/${job_name}/${_err_f}" >> /tmp/${_r_stdoutfile}
		echo
		#
		# if $_r_vbr_pid is alive then:
		# 	if vbr is still running in remote host
		# 		sleep & continue
		#   else:
		#		check/update status and exit
		# else:
		# 	exit with failed status
		if ! [ -z "${_r_vbr_pid}" ]; then ## when vbr initializaion fails, it will not run
			_vbr_sts=$(${SSH} -q ${transfer_init_host} -p 22 "[ ! -z '${_r_vbr_pid}' -a -d '/proc/${_r_vbr_pid}' ] && { echo '${RUNNING_STR}'; }")
			if [ "${_vbr_sts}" = "${RUNNING_STR}" ]; then
				sleep ${AUN_ENGN_MON_TIMESEC}
				continue
			fi
		fi
		#
		# Vbr is complete/ is not running.
		# If 'successfully completed' string is in the file, then its done
		_tmp_00=$(cat /tmp/${_r_stdoutfile} | grep 'Object replication complete!' 2>/dev/null)
		if [ -z "${_tmp_00}" ]; then
			# check error file to confirm failure
			_tmp_00=$(cat /tmp/${_r_stdoutfile} | grep 'FAILED' 2>/dev/null)
			if ! [ -z "${_tmp_00}" ]; then
				log "${TE}" "[${job_name}] transfer failed" "${job_spcfclog_abs_f}"
			else
				log "${TE}" "[${job_name}] transfer failed with unknown error. Please check manually." "${job_spcfclog_abs_f}"
			fi
			#
			# mark as failed & Exit
			move_tofailq "${RUNNINGREQUESTS_DIR}/${job_name}.req"
			update_transferSTS "${job_name}" "${TS_STATE_FAILED}"
			break
		fi
		#
		# mark as complete & Exit
		mv "${RUNNINGREQUESTS_DIR}/${job_name}.req" "${COMPLETEDREQUESTS_DIR}" 2>&1>/dev/null
		update_transferSTS "${job_name}" "${TS_STATE_SUCCEEDED}"
		log "${TE}" "[${job_name}] Transfer completed successfully !!!." "${job_spcfclog_abs_f}"
		break
	done
	#
	# clean temp/dummy files
	[ -f ${_dummy_01_abs} ] && rm -f ${_dummy_01_abs} 2>&1>/dev/null  ## need secure delete, use test in variable value
	#
	# remove engine lock file
	updateEngine_LF ${job_name} ${ENGN_LOCKACTION_DEL_STR}
	#
	# run post tasks
	run_postengine_task
}


#######################################################################
# 			EOF functions
#######################################################################

#
# Engine
#
function engine {
	if ! run_preengine_task "$@"; then
		log "${TE}" "[${job_name}] pre-engine task failed" "${job_spcfclog_abs_f}"
		update_transferSTS "${job_name}" "${TS_STATE_FAILED}"
		#
		# remove engine lock file
		updateEngine_LF ${job_name} ${ENGN_LOCKACTION_DEL_STR}
		#
		# exit
		exit ${PRE_ENGNCHK_FAILED}
	fi

	log "${TE}" "[${job_name}] Pre-check before starting engine completed successfully" "${job_spcfclog_abs_f}"
	#
	# create job folder in source cluster
	rcode=$(${SSH} -q ${transfer_init_host} -p 22 "mkdir -p ${VBRCONFIG_LANDING_BASE}/${job_name} 2>&1 >/dev/null; echo \$?;")
	if [ ${rcode} -ne 0 ]; then
		log "${TE}" "[${job_name}] Error while creating directory ${VBRCONFIG_LANDING_BASE}@${transfer_init_host}" "${job_spcfclog_abs_f}"
		reject_job ${job_name}
		update_transferSTS "${job_name}" "${TS_STATE_FAILED}"
		#
		# demo code
		updateEngine_LF ${job_name} ${ENGN_LOCKACTION_DEL_STR}
		# eof demo code
		#
		exit ${PRE_ENGNCHK_FAILED}
	fi
	#
	# move configuration file to source cluster
	${SCP} -q -P 22 ${src_transfer_ini_file_abs_f} ${SCP_D_USER}@${transfer_init_host}:${VBRCONFIG_LANDING_BASE}/${job_name} \
		2> >(gawk $'{print strftime("%F %T", systime())" ['${TE}']", $0}' >&2)  >>${STDERRFILE}
	rcode=$?
	if [ ${rcode} -ne 0 ]; then
		log "${TE}"  "[${job_name}] Error occurred while moving config file ${transfer_ini_file_f} to source cluster node."  "${job_spcfclog_abs_f}"
		log "${TE}"  "[${job_name}] Process is cancel for now. View ${STDOUTFILE} for more detail"  "${job_spcfclog_abs_f}"
		reject_job ${job_name}
		update_transferSTS "${job_name}" "${TS_STATE_FAILED}"
		#
		# demo code
		updateEngine_LF ${job_name} ${ENGN_LOCKACTION_DEL_STR}
		# eof demo code
		#
		exit ${PRE_ENGNCHK_FAILED}
	fi
	#
	# Init transfer	& monitor
	# Calculate timing
	# Run post tasks
	autonomous_engine &
#	exit 0
} # EOF engine
engine "$@"
