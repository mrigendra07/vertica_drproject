#!/bin/bash

#######################################################################
#			Transfer Pre-processor (TPP)
#----------------------------------------------------------------------
# 0. move job from readyRequests to runningRequests
# 1. get new jobs
# 2. validate every jobs, if fails then move to failed
# 3. check eligibility
#######################################################################
source ${BASE_DIR}/status_log_handler.sh
source ${BASE_DIR}/vbr_config.sh
source ${BASE_DIR}/database.sh
source ${BASE_DIR}/utility/vtka_infra.dat
source ${BASE_DIR}/utility/pwd.dat
#
# global temp variables
cur_job_spcfclog_f=
cur_job_spcfclog_abs_f=
jobs_cnt_toprocess=0
cur_requset=
cur_request_sts_abs_f=

cur_SOURCE_DATABASE=
cur_SOURCE_USER=
cur_DESTINATION_DATABASE=
cur_DESTINATION_USER=
cur_TRANSFER_MODE=

cur_SOURCE_CLUSTER_VIP=
cur_DESTINATION_CLUSTER_VIP=
########################################################################
# verify only single instance is running
# Note: required when multiple transfer is initiated at the same time
# If this script doesn't uses global log file, then multiple instance
# can run at the same time
########################################################################
#mkdir -p ${LF_ABS_DIR} && cat /dev/null >> ${TP_ABS_LF}
#read last_tp_pid < ${TP_ABS_LF}
##
## wait until another process ends
#while [ ! -z "${last_tp_pid}" -a -d /proc/${last_tp_pid} ]; do
#    sleep ${LF_WAIT_TIMESEC}
#done
#echo $$ > ${TP_ABS_LF}

#######################################################################
# 			functions
#######################################################################

function check_elig() {
	#
	# We verify if the schema is eligible for dr-replication or not.
	#
	# Return:
	#  0=eligible
	#  1=not-eligible
	#
	#------------------------------------------------------------------------
	#				LOGIC
	# 1. if check_elig_lockfile exists: Wait for 1 sec and check again
	# 2. Create check_elig_lockfile [ trap : rm -f check_elig_lockfile ]
	# 3. Get all currently running transfer requests files
	# 4. For every running transfers:
	#        - If cur_SOURCE_CLUSTER_VIP is equal to  source_cluster_vip:
	#              -- return 1
	#          elif cur_DESTINATION_CLUSTER_VIP is equal to destination_cluster_vip:
	#              -- return 1
	# 5. Remove check_elig_lockfile
	# 6. return 0
	#------------------------------------------------------------------------
	#
	# check lock
	return 0
	while [ "$(elig_lockfile_exists)" = "yes" ]; do
		log "${TPP}"  "[${tr_job_reqid}] Lock file ${TRNS_ELIG_LOCK_ABS_F} still exists. Waiting for lock release"  "${cur_job_spcfclog_abs_f}"
		sleep 7
	done
	if create_elig_lockfile; then
		#------------------------------------------------#
		# create trap to make sure lock will be released #
		# even when error occurs                         #
		#------------------------------------------------#
		log "${TPP}"  "[${tr_job_reqid}] Error creating lock file ${TRNS_ELIG_LOCK_ABS_F}"  "${cur_job_spcfclog_abs_f}"
		return 1
	fi
	#
	# check source and destination cluster name for all running transfers
	for running_req_f in $(ls ${RUNNINGREQUESTS_DIR}/*.req 2>/${DEVNULL} | sort); do
		#
		_running_src_vip="$(cat ${running_req_f} | grep 'source_cluster_vip' | cut -d'=' -f2|awk '{$1=$1};1' | sed -e 's/\r//g')"
		_cur_src_vip="${cur_SOURCE_CLUSTER_VIP}"
		[ "${_cur_src_vip}" = "${_running_src_vip}" ] && {
			rm_elig_lockfile
			return 1
		}
		#
		_running_dst_vip="$(cat ${running_req_f} | grep 'destination_cluster_vip' | cut -d'=' -f2|awk '{$1=$1};1' | sed -e 's/\r//g')"
		_cur_dst_vip="${cur_DESTINATION_CLUSTER_VIP}"
		[ "${_cur_dst_vip}" = "${_running_dst_vip}" ] && {
			rm_elig_lockfile
			return 1
		}
	done
	#
	# remove lock file and return
	rm_elig_lockfile
	return 0
}

function parse_request {
    #
	# We parse request file here assuming all the fields exist and are valid.
	cur_req_f=${1}
	tr_job_reqid=$(cat ${RUNNINGREQUESTS_DIR}/${cur_req_f}                 | grep 'tr_job_reqid'             | cut -d'=' -f2|awk '{$1=$1};1' | sed -e 's/\r//g')
	cur_SCHEMA_NAME=$(cat ${RUNNINGREQUESTS_DIR}/${cur_req_f}              | grep 'schema_name'              | cut -d'=' -f2|awk '{$1=$1};1' | sed -e 's/\r//g')
	cur_SOURCE_CLUSTER_VIP=$(cat ${RUNNINGREQUESTS_DIR}/${cur_req_f}       | grep 'source_cluster_vip'       | cut -d'=' -f2|awk '{$1=$1};1' | sed -e 's/\r//g')
	cur_DESTINATION_CLUSTER_VIP=$(cat ${RUNNINGREQUESTS_DIR}/${cur_req_f}  | grep 'destination_cluster_vip'  | cut -d'=' -f2|awk '{$1=$1};1' | sed -e 's/\r//g')
}

function prepare_vbr_ini_file {
    # ret code:
    #  0=success
    #  1=failed

	#
	# First, collect all required info
	cur_OBJECT_NAME=${cur_SCHEMA_NAME}
	cur_SOURCE_DATABASE=${database[${cur_SOURCE_CLUSTER_VIP}]}
	cur_SOURCE_USER=${sync_dbuser}
	cur_DESTINATION_DATABASE=${database[${cur_DESTINATION_CLUSTER_VIP}]}
	cur_DESTINATION_USER=${sync_dbuser}
	#
	# Mapping source database nodes and destination hosts list for mapping
	#
	_db_usr_tmp="${cur_SOURCE_DATABASE}_${cur_SOURCE_USER}"
	_srv_db_pwd="${db_password[${_db_usr_tmp}]}"
	#
	# get source nodes
	[ -z "${port[${cur_SOURCE_CLUSTER_VIP}]}" ] && {
		log "${TPP}"  "[${cur_req}] Port for VIP ${cur_SOURCE_CLUSTER_VIP} not found."  "${cur_job_spcfclog_abs_f}"
		return 1
	}
	[ -z "${db_password[${_db_usr_tmp}]}" ] && {
		log "${TPP}"  "[${cur_req}] Password for ${_db_usr_tmp} not found."  "${cur_job_spcfclog_abs_f}"
		return 1
	}
	_src_nodes=($(get_vtka_nodes_hosts "${cur_SOURCE_CLUSTER_VIP}" "${cur_SOURCE_DATABASE}" "${port[${cur_SOURCE_CLUSTER_VIP}]}" "${cur_SOURCE_USER}" "${_srv_db_pwd}" "nodes"))
	if [ $? -ne 0 ]; then
		log "${TPP}"  "[${cur_req}] Error occurred while getting source database cluster nodes name. Check application log/errfile for more details."  "${cur_job_spcfclog_abs_f}"
		return 1
	fi
	# get source hosts
	# we use them to initiate vbr. script
	_src_hosts=($(get_vtka_nodes_hosts "${cur_SOURCE_CLUSTER_VIP}" "${cur_SOURCE_DATABASE}" "${port[${cur_SOURCE_CLUSTER_VIP}]}" "${cur_SOURCE_USER}" "${_srv_db_pwd}" "hosts"))
	if [ $? -ne 0 ]; then
		log "${TPP}"  "[${cur_req}] Error occurred while getting source database cluster hosts name. Check application log/errfile for more details."  "${cur_job_spcfclog_abs_f}"
		return 1
	fi
	#
	# get destination hosts
	_db_usr_tmp="${cur_DESTINATION_DATABASE}_${cur_DESTINATION_USER}"
	_dst_db_pwd="${db_password[${_db_usr_tmp}]}"
	#
	[ -z "${port[${cur_DESTINATION_CLUSTER_VIP}]}" ] && {
		log "${TPP}"  "[${cur_req}] Port for VIP ${cur_DESTINATION_CLUSTER_VIP} not found."  "${cur_job_spcfclog_abs_f}"
		return 1
	}
	[ -z "${db_password[${_db_usr_tmp}]}" ] && {
		log "${TPP}"  "[${cur_req}] Password for typeset ${_db_usr_tmp} not found."  "${cur_job_spcfclog_abs_f}"
		return 1
	}
	_dst_hosts=($(get_vtka_nodes_hosts "${cur_DESTINATION_CLUSTER_VIP}" "${cur_DESTINATION_DATABASE}" "${port[${cur_DESTINATION_CLUSTER_VIP}]}" "${cur_DESTINATION_USER}" "${_dst_db_pwd}" "hosts"))
	if [ $? -ne 0 ]; then
		log "${TPP}"  "[${cur_req}] Error occurred while getting destination database cluster hosts name. Check application log/errfile for more details."  "${cur_job_spcfclog_abs_f}"
		return 1
	fi
	if [ ${#_src_nodes[@]} -ne ${#_dst_hosts[@]} ]; then
		log "${TPP}"  "[${cur_req}] source nodes count ${#_src_nodes[@]} and destination hosts count ${#_dst_hosts[@]} not matching"  "${cur_job_spcfclog_abs_f}"
		return 1
	fi
	#
	# we create vbr ini file here
    cur_req=${1}
	ini_f_name="${cur_req}_${cur_SCHEMA_NAME}.ini"
	snapshot_name="${cur_req}_${cur_SCHEMA_NAME}"
	# start creating
	cat /dev/null                                                           >  ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${SEC_NAME_MISC}"                                                 >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${snapshotName_item}       = "${snapshot_name}                    >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${dest_verticaBinDir_item} = "${dest_verticaBinDir_val}           >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${restorePointLimit_item}  = "${restorePointLimit_val}            >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${objects_item}            = "${cur_SCHEMA_NAME}                  >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${objectRestoreMode_item}  = "${objectRestoreMode_val}            >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${tempDir_item}            = "${tempDir_val}                      >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${retryCount_item}         = "${retryCount_val}                   >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${retryDelay_item}         = "${retryDelay_val}                   >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo ""                                                                 >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${SEC_NAME_DATABASE}"                                             >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${dbName_item}             = "${cur_SOURCE_DATABASE,,}              >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${dbUser_item}             = "${cur_SOURCE_USER}                  >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${dest_dbName_item}        = "${cur_DESTINATION_DATABASE,,}         >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${dest_dbUser_item}        = " ${cur_DESTINATION_USER}            >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo ""                               		          		            >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${SEC_NAME_PASSWORDS}"                                            >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${dbPassword_item}         = ""${_srv_db_pwd}"                    >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${dest_dbPassword_item}    = ""${_dst_db_pwd}"                    >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo ""                                         			            >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${SEC_NAME_MAPPING}"                                              >> ${ENGN_INPUT_DIR}/${ini_f_name}
	#
	# source db nodes to destination host mapping
	for index in ${!_src_nodes[@]}; do
		echo "${_src_nodes[${index}]}" " = ${_dst_hosts[${index}]}"         >> ${ENGN_INPUT_DIR}/${ini_f_name}
	done
	echo ""                                         			            >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo ""                                         			            >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${SEC_NAME_TRANSMISSION}"                                         >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${encrypt_item}               = "${encrypt_val}                   >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${checksum_item}              = "${checksum_val}                  >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${port_rsync_item}            = "${port_rsync_val}                >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${serviceAccessUser_item}     = "${serviceAccessUser_val}         >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${total_bwlimit_backup_item}  = "${total_bwlimit_backup_val}      >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${concurrency_backup_item}    = "${concurrency_backup_val}        >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${concurrency_restore_item}   = "${concurrency_restore_val}       >> ${ENGN_INPUT_DIR}/${ini_f_name}
	echo "${total_bwlimit_restore_item} = "${total_bwlimit_restore_val}     >> ${ENGN_INPUT_DIR}/${ini_f_name}
	#
	# Note: we assume the ini file is correct. May need to verify the ini file content later
	return 0
}

#######################################################################
# 			EOF functions
#######################################################################

#
# Transfer Pre-processor body
#
function transfer_preprocessor {
	jobs_cnt_toprocess=${1}
	#
	# move jobs to runningRequests
	_jlist=()
	for request_f in `ls -tr ${READYREQUESTS_DIR} |rev|cut -d'/' -f1|rev| sed -n "${REQUESTFILE_REGEX}" | head -n ${jobs_cnt_toprocess}`; do
		mv ${READYREQUESTS_DIR}/${request_f} ${RUNNINGREQUESTS_DIR} \
			2> >(gawk $'{print strftime("%F %T", systime())" ['${TPP}:\ ${request_f}'] Error while moving.", $0}' >&2)  >>${STDERRFILE}
		#
		# add to array if move is done
		# failed job will be tried later when all jobs are moved.
		if [ ${?} -eq 0 ]; then
			_jlist+=(${request_f})
			#
			# update retry count
			cur_requset=$(echo ${request_f} | cut -d'.' -f1)
			incrementRetryCnt "${cur_requset}"
		fi
	done
	#
	# process all possible jobs
	# Note: job specific log is generated from here onwards
	#
	for request_f in ${_jlist[@]}; do

		cur_requset=$(echo ${request_f} | cut -d'.' -f1)
		# demo code
		updateEngine_LF ${cur_requset} ${ENGN_LOCKACTION_ADD_STR}
		# eof demo code

		#
		# init log file
		cur_job_spcfclog_f="${cur_requset}.log"
		cur_job_spcfclog_abs_f="${JOB_SPCFC_LOG_DIR}/${cur_job_spcfclog_f}"
		touch "${cur_job_spcfclog_abs_f}"
		#
		# update transfer job status
		update_transferSTS "${cur_requset}" "${TS_STATE_RUNNING}"
		#
		# parse request file
		parse_request "${request_f}"
		#
		# verify eligibility
		check_elig "${cur_SCHEMA_NAME}" "${cur_SOURCE_CLUSTER_VIP}" "${cur_DESTINATION_CLUSTER_VIP}"
		if [ ${?} -ne 0 ]; then
			#
			# if not eligible then
			# revert back job to ready state & Exit
			update_transferSTS "${cur_requset}" "${TS_STATE_REVERTED}"
			mv ${RUNNINGREQUESTS_DIR}/${request_f} ${READYREQUESTS_DIR} 2>&1>/dev/null

			# demo code
			updateEngine_LF ${cur_requset} ${ENGN_LOCKACTION_DEL_STR}
			# eof demo code

			continue
		fi
		#
		# we create configuration file here
		prepare_vbr_ini_file "${cur_requset}"
		if [ ${?} -ne 0 ]; then
			#
			# mark as failed, move to failed & Exit
			move_tofailq "${RUNNINGREQUESTS_DIR}/${cur_requset}.req"
			update_transferSTS "${cur_requset}" "${TS_STATE_FAILED}"

			# demo code
			updateEngine_LF ${cur_requset} ${ENGN_LOCKACTION_DEL_STR}
			# eof demo code

			continue
		fi
		#-------------------------------------------------
		# start engine
		#-------------------------------------------------
		_transfer_init_host="${_src_hosts[0]}"

		[ -z ${_transfer_init_host} ] && {
			log "${TPP}"  "[${cur_requset}] cannot get transfer initiator node from connection file. Check nodes in connection file for cluster ${cur_DESTINATION_CLUSTER}"  "${cur_job_spcfclog_abs_f}"
			echo "${TS_STATE_FAILED}" > ${cur_request_sts_abs_f}
			move_tofailq "${RUNNINGREQUESTS_DIR}/${cur_requset}.req"
			# demo code
			updateEngine_LF ${cur_requset} ${ENGN_LOCKACTION_DEL_STR}
			[ -f ${RUNNINGREQUESTS_DIR}/${request_f} ] && {
			mv ${RUNNINGREQUESTS_DIR}/${request_f} ${FAILEDREQUESTS_DIR} 2>&1>/dev/null ; }
			# eof demo code \
			continue;
		}
		${BASH} ${EX_MODE} ${BASE_DIR}/${TRANSFER_ENGINE} ${cur_requset} ${_transfer_init_host}

	done
} # EOF transfer_preprocessor
transfer_preprocessor "$@"
