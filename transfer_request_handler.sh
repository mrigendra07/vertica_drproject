#!/bin/bash
#######################################################################
# 				Transfer Request Handler
#----------------------------------------------------------------------
# 1. check available job
# 2. if new job available
# 3. verify and move to readyRequests queue
# 4. Move failed job to readyRequests or gaveupRequests
######################################################################

source ${BASE_DIR}/status_log_handler.sh

########################################################################
# verify only single instance is running
# Note: required when multiple transfer is initiated at the same time
########################################################################
mkdir -p ${LF_ABS_DIR} && cat /dev/null >> ${TRH_ABS_LF}
read last_trh_pid < ${TRH_ABS_LF}
#
# wait until another process ends
while [ ! -z "${last_trh_pid}" -a -d /proc/${last_trh_pid} ]; do
    sleep ${LF_WAIT_TIMESEC}
done
echo $$ > ${TRH_ABS_LF}

#######################################################################
# 			functions
#######################################################################
function validate_reqfile(){
	#
	# We do transfer request file content validation here
	#
	# Return:
	#  0 : success
	#  1 : fail, file doesn't exists
	#  2 : fail, content missing or invalid
	_reqfile="${1}"
	[ -f ${_reqfile} ] || {
		return 1
	}
	for rf_item in ${REQUESTFILE_ITEMS[@]}; do
		[ $( cat ${_reqfile}|grep -i "${rf_item}" | wc -l ) -eq 0 ] && {
			return 2
		}
	done
	#
	# everything fine
	return 0
}

#######################################################################
# verify every new job here
# if fails while verification, move it to failedRequests queue
#######################################################################
for request_f in  `ls -tr ${NEWREQUESTS_DIR}/*[0-9]*.req 2>/dev/null |rev|cut -d'/' -f1|rev| sed -n "${REQUESTFILE_REGEX}"`; do
	job_name=$(echo ${request_f} |  cut -d'.' -f1)
	log ${TRH} "New request available. Job name ${job_name}"
	#
	# validate request file
	validate_reqfile "${NEWREQUESTS_DIR}/${request_f}"
	ex_code=$?
	if [ ${ex_code} -ne 0 ]; then
		if [ ${ex_code} -eq 1 ]; then
			log ${TRH}  "[${job_name}] Request file doesn't exists, content validation failed for job ${job_name}"
		elif [ ${ex_code} -eq 2 ]; then
			log ${TRH}  "[${job_name}] Request file content is invalid fo job ${job_name}. Request file ${request_f}"
			log ${TRH}  "[${job_name}] Rejecting job ${job_name}"
			reject_job "${NEWREQUESTS_DIR}/${job_name}.req"
		fi
		continue
	fi
	#
	# move to readyRequests
	_output=$(mv ${NEWREQUESTS_DIR}/${request_f} ${READYREQUESTS_DIR} 2>&1)
	[ ! -z "${_output}" ] && { log ${TRH} "Error while moving ${job_name} to ${READYREQUESTS_DIR}. ErrMsg: "${_output};
						  continue
	}
	log ${TRH} "[${job_name}] Request file ${request_f} moved to readyRequests:${READYREQUESTS_DIR}"
done

#
# Move failed job to either gaveupRequests or readyRequests
#
for request_f in  `ls -tr ${FAILEDREQUESTS_DIR}/*[0-9]*.req  2>/dev/null |rev|cut -d'/' -f1|rev| sed -n "${REQUESTFILE_REGEX}"`; do
	cur_requset=$(echo ${request_f} |  cut -d'.' -f1)
	job_maxRetry_reached ${cur_requset}
	if [ ${?} -eq 0 ]; then
		# move to failedRequests
		mv ${FAILEDREQUESTS_DIR}/${cur_requset}.req ${READYREQUESTS_DIR} \
			2> >(gawk $'{print strftime("%F %T", systime())" ['${TRH}']", $0}' >&2)  >>${STDERRFILE}
	else
		# move to gaveupRequests
		mv ${FAILEDREQUESTS_DIR}/${cur_requset}.req ${GAVEUPREQUESTS_DIR} \
			2> >(gawk $'{print strftime("%F %T", systime())" ['${TRH}']", $0}' >&2)  >>${STDERRFILE}
	fi
done
