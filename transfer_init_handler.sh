#!/bin/bash
#######################################################################
#			Transfer Initialization handler (TIH)
#----------------------------------------------------------------------
# 1. checks for available slots in TE
# 2. If available then, checks ready queue and suggest for new
#    transfer to request-preprocessor(RPP)
#######################################################################

source ${BASE_DIR}/status_log_handler.sh

########################################################################
# verify only single instance is running
# Note: required when multiple transfer is initiated at the same time
########################################################################
mkdir -p ${LF_ABS_DIR} && cat /dev/null >> ${TIH_ABS_LF}
read last_tih_pid < ${TIH_ABS_LF}
#
# wait until another process ends
while [ ! -z "${last_tih_pid}" -a -d /proc/${last_tih_pid} ]; do
    sleep ${LF_WAIT_TIMESEC}
done
echo $$ > ${TIH_ABS_LF}

########################################################################
# check for available TE slot
########################################################################
# Clean orphan transfer status and engine lock file
# Get max parallel thread allowed, max_thread_count
# Count number of running transfer and engine lock file count per transfer, rnin_trnfs & te_lf_cnt
# For every rnin_trnfs & te_lf_cnt count do not match:
# 		call it orphans which are not common and copy them to respective orphan dir,
#       later clean them all
#
# Note:
# user should not be able to initiate new transfer when there is
# more than 3 orphan transfers
########################################################################
#
# check orphan jobs
max_thread_count=
jobs_running=
max_thread_count=$( cat ${STATUSFILE_ABS_F} | grep "${parallel_transfer_str}" | cut -d '=' -f2 | head -n 1)
jobs_running=$( ls ${RUNNINGREQUESTS_DIR}/*.req 2>/${DEVNULL} | sort | wc -l)
if ! $(is_number "${max_thread_count}"); then
	log "${TIH}" "Parallel_transfer value in configuration file ${STATUSFILE_ABS_F} is not number. Using default value ${DEFAULT_ENGINE_SLOT_CNT}"
	max_thread_count=${DEFAULT_ENGINE_SLOT_CNT}
fi
if [ ${jobs_running} -ge ${max_thread_count} ]; then
	# this may happen when user decreases parallel_transfer value in configuration
	log "${TIH}" "Engine is busy, cannot run new transfer at the moment, exiting"
	exit 0
else
	free_te_slots=`expr ${max_thread_count} - ${jobs_running}`
fi
#
# check readyRequest
ready_jobs_cnt=$( ls -tr ${READYREQUESTS_DIR} 2>${DEVNULL} |rev|cut -d'/' -f1|rev| sed -n "${REQUESTFILE_REGEX}" | wc -l )
if [ ${ready_jobs_cnt} -eq 0 ]; then
	#log ${TIH} "No new request found."
	exit 0
fi
#
# suggest TPP for new transfer
if [ ${free_te_slots} -ge ${ready_jobs_cnt} ]; then
	# max number of parallel transfer possible is ${ready_jobs_cnt}
	${BASH} ${EX_MODE} ${BASE_DIR}/${TRANSFER_PRE_PROCESSOR} ${ready_jobs_cnt}
else
	${BASH} ${EX_MODE} ${BASE_DIR}/${TRANSFER_PRE_PROCESSOR} ${free_te_slots}
fi
