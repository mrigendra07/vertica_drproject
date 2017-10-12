#!/bin/bash
#######################################################################
#
# This file contains all constant variables that are used by other
# components. These variables are used by sourcing. Also, required
# files/folders are created in this script
#
#######################################################################
#
# bins
BASH="/bin/bash"
SCP="/usr/bin/scp"
SSH="/usr/bin/ssh"
DEVNULL="/dev/null"
VSQLBIN='/opt/vertica/bin/vsql'
#
# tmp dir
DEFAULT_TMP_DIR="/tmp/drtemp"
#
# vbr
VBRPY="vbr.py"
#
# regex
REQUESTFILE_REGEX='/\b[0-9]\{16\}.req\b/p'
S_SCHEMA_REGEX='^S0-?[0-9]{6,6}_[a-zA-Z]$'
#
# strings
SUCCESS_STR="success"
FAILURE_STR="fail"
RUNNING_STR="running"
TRUE_STR='true'
FALSE_STR='false'
MOVE_TOFAILEDQUEUE="move_tofailedqueue"
MOVE_TOGAVEUPQUEUE="move_togaveupqueue"
ENGN_LOCKACTION_ADD_STR="add_engine_lf"
ENGN_LOCKACTION_DEL_STR="del_engine_lf"
#
# jobs
iJOBS_MAX_RETRYLIMIT=1
# jobs directory
JOB_DIR="jobs"
JOBS_HOME="${BASE_DIR}/${JOB_DIR}"   ## may need to verify empty $BASE_DIR
NEWREQUESTS="newRequests"
NEWREQUESTS_DIR="${JOBS_HOME}/${NEWREQUESTS}"
READYREQUESTS="readyRequests"
READYREQUESTS_DIR="${JOBS_HOME}/${READYREQUESTS}"
RUNNINGREQUESTS="runningRequests"
RUNNINGREQUESTS_DIR="${JOBS_HOME}/${RUNNINGREQUESTS}"
FAILEDREQUESTS="failedRequests"
FAILEDREQUESTS_DIR="${JOBS_HOME}/${FAILEDREQUESTS}"
GAVEUPREQUESTS="gaveupRequests"
GAVEUPREQUESTS_DIR="${JOBS_HOME}/${GAVEUPREQUESTS}"
COMPLETEDREQUESTS="completedRequests"
COMPLETEDREQUESTS_DIR="${JOBS_HOME}/${COMPLETEDREQUESTS}"
REJECTEDREQUESTS="rejectedRequests"
REJECTEDREQUESTS_DIR="${JOBS_HOME}/${REJECTEDREQUESTS}"

#
# job log
JOB_SPCFC_LOG_DIR="${TMP_DIR}/logs"
#
# engine
ENGN_INPUT_DIR="${TMP_DIR}/engine"
AUN_ENGN_MON_TIMESEC=15
DEFAULT_ENGINE_SLOT_CNT=1
#
# components
TRH="TRH"
TIH="TIH"
TPP="TPP"
TE="TE"
SLH="SLH"
#
# status file
JOB_RETRY_F="._retres.sts"
JOB_RETRY_ABS_F="${TMP_DIR}/${JOB_RETRY_F}"
#dummy files/folder base
DUMMY_DIR="dummy"
DUMMY_ABS_DIR="${TMP_DIR}/${DUMMY_DIR}"
#
# component status file
TRH_STS_F="${TMP_DIR}/._transfer_reqhandler.sts"
#
# lock files
LF_DIR="._locks"
LF_ABS_DIR="${TMP_DIR}/${LF_DIR}"
LF_WAIT_TIMESEC=3
ENGN_LOCK_DIR="engine"
ENGN_LOCK_ABS_DIR="${LF_ABS_DIR}/${ENGN_LOCK_DIR}"
# transfer eligibility lock file
TRNS_ELIG_LOCK_F="transfer_elig_lf.lock"
TRNS_ELIG_LOCK_DIR="transfer_elig"
TRNS_ELIG_LOCK_ABS_DIR="${LF_ABS_DIR}/${TRNS_ELIG_LOCK_DIR}"
TRNS_ELIG_LOCK_ABS_F="${TRNS_ELIG_LOCK_ABS_DIR}/${TRNS_ELIG_LOCK_F}"

#
#
TRH_LF="._trh_lf.pid"
TRH_ABS_LF="${LF_ABS_DIR}/${TRH_LF}"
TIH_LF="._tih_lf.pid"
TIH_ABS_LF="${LF_ABS_DIR}/${TIH_LF}"
TP_LF="._tp_lf.pid"
TP_ABS_LF="${LF_ABS_DIR}/${TP_LF}"
#
# job status
JS_DIR="transfer_status"
JS_ABS_DIR="${TMP_DIR}/${JS_DIR}"
#
# orphan transfers
OT_DIR="orphans"
OT_ABS_DIR="${TMP_DIR}/${OT_DIR}"
OT_TS_DIR="running_transfer"
OT_TS_ABS_DIR="${OT_ABS_DIR}/${OT_TS_DIR}"
OT_TELF_DIR="te_lfile"
OT_TELF_ABS_DIR="${OT_ABS_DIR}/${OT_TELF_DIR}"
#
# transfer states
TS_STATE_RUNNING="RUNNING"
TS_STATE_FAILED="FAILED"
TS_STATE_SUCCEEDED="SUCCEEDED"
TS_STATE_REVERTED="REVERTED"


########################################################################
# Custom exit codes
########################################################################
#
# code 169: Error during validation process. this should not mark job as failed but leave in the readyRequest queue
PRE_ENGNCHK_FAILED=169
#
# code 170: Transfer Engine started normally
ENGN_STRTED_NORMALLY=170
#
# code 170: Error during transfer, after the transfer has started. This should immediately move the job to failed and
# block further execution
TRANSFER_FAILED=171


#######################################################################
#				configuration file part
#######################################################################
logfile_str="log_file"
configfile_str="configfile"
transfer_status_base_str="transfer_status_base"
parallel_transfer_str="parallel_transfer"
#
# replication initialization node
SCP_D_USER="dbadmin"
VBRCONFIG_LANDING_BASE="/home/dbadmin/drreplication/inifiles"
VBR_OUTPUTLOG_DIR="/home/dbadmin/drreplication/vbr_outputs"

#######################################################################
#				Request file contents parameters
#######################################################################
REQUESTFILE_ITEMS=(tr_job_reqid schema_name source_cluster_vip destination_cluster_vip)


#######################################################################
# Create required files/folders if doesn't exists
#######################################################################
mkdir -p ${DEFAULT_TMP_DIR}
mkdir -p ${JOBS_HOME}
mkdir -p ${NEWREQUESTS_DIR}
mkdir -p ${READYREQUESTS_DIR}
mkdir -p ${RUNNINGREQUESTS_DIR}
mkdir -p ${FAILEDREQUESTS_DIR}
mkdir -p ${GAVEUPREQUESTS_DIR}
mkdir -p ${COMPLETEDREQUESTS_DIR}
mkdir -p ${REJECTEDREQUESTS_DIR}
mkdir -p ${JOB_SPCFC_LOG_DIR}
mkdir -p ${ENGN_INPUT_DIR}
mkdir -p ${LF_ABS_DIR}
mkdir -p ${JS_ABS_DIR}
mkdir -p ${DUMMY_ABS_DIR}
mkdir -p ${ENGN_LOCK_ABS_DIR}
mkdir -p ${TRNS_ELIG_LOCK_ABS_DIR}
mkdir -p ${OT_TS_ABS_DIR}
mkdir -p ${OT_TELF_ABS_DIR}
# below folders: create in transfer initiator host of source cluster
#mkdir -p ${VBRCONFIG_LANDING_BASE}
#mkdir -p ${VBR_OUTPUTLOG_DIR}

touch ${JOB_RETRY_ABS_F}
touch ${TRH_STS_F}
touch ${TRH_ABS_LF}
touch ${TIH_ABS_LF}
touch ${TP_ABS_LF}
touch ${STATUSFILE_ABS_F}
