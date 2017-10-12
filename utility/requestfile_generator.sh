#!/bin/bash
#######################################################################
#               Request file generator
#----------------------------------------------------------------------
# Author          : Bhupal Rai
# Release version : 1.0.0
# Updated by      : Bhupal Rai
# Last updated    : 2017 AUG 25
#----------------------------------------------------------------------
# Script to generate request file based on the schema, source vertica vip
# provided.
# Initiated by dashboard.
#
# Parameters: <S_SCHEMA> <SOURCE_VERTICA_VIP>
#
#######################################################################
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )"/../ && pwd )"
NEWREQUESTS="newRequests"
NEWREQUESTS_DIR="${BASE_DIR}/jobs/${NEWREQUESTS}"
LOGFILE="requestgenerator.log"
LOGFILE_ABS_F="${BASE_DIR}/tmp/logs/${LOGFILE}"
#
# Request file contents
REQUESTFILE_CONTENTS=(tr_job_reqid schema_name source_cluster_vip destination_cluster_vip)

#######################################################################
# Functions
#######################################################################
function usage(){
echo "
Usage file:
-------------------------------------------------------------
 NAME:
  $0

 USAGE:
  bash $0 -h|--help
  bash $0 -s <schema_name>|--schema=<schema_name> -v <vip_name>|--vip=<vip_name>

 DESCRIPTION:
  Script to generate request file based on the schema and source vertica vip name provided.

 PARAMETERS:
  -h|--help                     : show help
  -s|--schema                   : requires schema name that is to be transferred
  -v|--vip                      : requires vip name of vertica cluster containing schema

 EXAMPLES:
  bash $0 --help
  bash $0 -s S0123001_A -v NVVIPPRODA
  bash $0 --schema=S0123001_A --vip=NVVIPPRODA
"
}

function log(){
	logmsg=${1}
	echo `date '+%Y-%m-%d %H:%M:%S'`" ${logmsg}" >> ${LOGFILE_ABS_F}
}

function exit0(){
	exit 0
}

function exit1(){
	exit 1
}

function usage_exit0(){
	usage
	exit0
}

function usage_exit1(){
	usage
	exit1
}

function syntxerr_usage_exit1(){
	echo -e "Syntax error occurred !"
	usage_exit1
}

function initialize {
	#
	# We do script initialization task here
	#
	[ -z ${S_SCHEMA} ] && { echo "S-Schema is empty";
		log "S-Schema is empty. Initialization failed !"; usage_exit1; }
	[ -z ${SOURCE_CLUSTER_VIP} ] && { echo "Source cluster VIP name is empty";
		log "Source cluster VIP name is empty. Initialization failed !"; usage_exit1; }
	log "Initialization done"
}

function parse_opts {
	#
	#  Parse arguments
	#
	params=( "$@" )
	[ ${#params[@]} -eq 0 ] && { syntxerr_usage_exit1; }
	#
	# start parsing
	optspec=":s:v:-:h"
	while getopts "$optspec" opt; do
		case ${opt} in
			-)
				#
				# handle long opts/args
				#
				[ "${OPTARG}" = 'help' ] && { usage_exit1; }
				#
				# verify argument format
				if [ ! $(expr "${OPTARG}" : ".*[=].*") -gt 0 ] || [ "$(echo ${OPTARG} | cut -d '=' -f 2)" = "" ]; then
					echo -e "Invalid argument format '--${OPTARG}'.\n"
					usage_exit1
				fi
				case "${OPTARG}" in
					schema=*)
						S_SCHEMA=${OPTARG#*=}
						S_SCHEMA=${S_SCHEMA^^}
						;;
					vip=*)
						SOURCE_CLUSTER_VIP=${OPTARG#*=}
						SOURCE_CLUSTER_VIP=${SOURCE_CLUSTER_VIP^^}
						;;
					*)
						if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
							echo -e "Unknown option --${OPTARG}\n" >&2
							usage_exit1
						fi
						;;
				esac;;
			#
			# short args
			s)
				S_SCHEMA="${OPTARG}"
				S_SCHEMA=${S_SCHEMA^^}
				;;
			v)
				SOURCE_CLUSTER_VIP=${OPTARG}
				SOURCE_CLUSTER_VIP=${SOURCE_CLUSTER_VIP^^}
				;;
			h)
				usage_exit0
				;;
			:)
				echo -e "Option -${OPTARG} requires an argument\n"
				usage_exit1
				;;
			*)
				echo -e " Invalid argument format '-${OPTARG}'.\n"
				usage_exit1
				;;
			\?)
				usage_exit1
				;;
		esac
	done
}

function validate_sschema(){
	#
	# S-schema format S0<3digit-CLIENT-ID><3digit-APP_ID>_<SINGLE_ALPHABET>
	s_schema=${1}
	s_schema_regx='^S0-?[0-9]{6,6}_[a-zA-Z]$'
	if [[ ${s_schema} =~ ${s_schema_regx} ]]; then
		return 0
	else
		# not matched
		return 1
	fi
}

function get_destn_clustervip(){
	#
	# Returns vertica destination cluster vip that is best suited for transfer
	# Destination cluster selection logic may vary later
	#
	# Parameters: source_cluster_name
	# rtype: string

	########################################################################
	# Logic:
	# 1. if source_cluster is production-a:
	#	     return destination cluster as dr-a
	#    if source_cluster is production-b:
	#	     return destination cluster as dr-b
	#    if source_cluster is production-c:
	#	     return destination cluster as dr-c
	#    else:
	#	     exit with error
	# Note:
	# 	Cluster and vip terms may have used interchangeably
	########################################################################
	_infrascript='../utility/vtka_infra.dat'
	source ${_infrascript}
	_src_vip="${1}"
	_destn_vip=""
	#
	#
	_destn_vip=${transfer[${_src_vip}]}
	#
	# return
	[ -z "${_destn_vip}" ] && {
		log "Destination vip for ${_src_vip} is empty. Please check ${_infrascript} for any errors";
		log "command: _destn_vip=${transfer[${_src_vip}]}"; }
	echo "${_destn_vip^^}"
	return 0
}

function generate_reqfile {
	args=( "$@" )
	parse_opts ${args[@]}
	#
	# Start script
	log "Start script"
	log "Working for ${S_SCHEMA}"
	initialize
	#
	# Init here, log file first
	touch ${LOGFILE_ABS_F} \
			2> >(gawk $'{print strftime("%F %T", systime())" ", $0}' >&2)
	if [ $? -ne 0 ]; then
		echo `date '+%Y-%m-%d %H:%M:%S'`" Error while validating logfile ${LOGFILE_ABS_F}"
		echo `date '+%Y-%m-%d %H:%M:%S'`" Using default location for logging /tmp/${LOGFILE}"
		LOGFILE_ABS_F="/tmp/${LOGFILE}"
	fi
	#
	# we validate parameter here
	if ! validate_sschema ${S_SCHEMA}; then
		log "S-Schema format didn't match ${S_SCHEMA}"
		exit1
	fi
	[ ! -d ${NEWREQUESTS_DIR} ] && {
		log "New requests directory ${NEWREQUESTS_DIR} not found. Please verify location exists and accessible to user `whoami`"
		exit1
	}
	#
	# get destination vip name
	destination_cluster_vip="$(get_destn_clustervip ${SOURCE_CLUSTER_VIP})"
	[ -z ${destination_cluster_vip} ] && exit1
	log "Source cluster vip: ${SOURCE_CLUSTER_VIP} destination cluster vip: ${destination_cluster_vip}"
	#
	# we generate request file here
	#--------------------------------------
	#       REQUEST FILE TEMPLATE
	#       file : 0170816154824238.req
	#--------------------------------------
	# tr_job_reqid=0170816154824238
	# schema_name=S0TEST01_A
	# source_cluster=DbaA
	# destination_cluster_group=DbaB
	#--------------------------------------
	#
	uid="$(date +'%Y%m%d%H%M%S%3N')"
	# make 3 digit year
	tr_job_reqid=${uid:1}
	schema_name=${S_SCHEMA}
	source_cluster_vip=${SOURCE_CLUSTER_VIP}
	destination_cluster_vip=${destination_cluster_vip}
	# validate item values
	for param in "${REQUESTFILE_CONTENTS[@]}"; do
		if [ -z "${!param}" ]; then
			log "Found empty parameter ${param}. Exiting further parameter check."
			exit1
		fi
	done
	log "Creating request ${tr_job_reqid}"
	cat /dev/null                                                   > ./${tr_job_reqid}.req 2>&1>/dev/null
	echo "tr_job_reqid=${tr_job_reqid}"                             >>./${tr_job_reqid}.req
	echo "schema_name=${schema_name}"                               >>./${tr_job_reqid}.req
	echo "source_cluster_vip=${source_cluster_vip}"                 >>./${tr_job_reqid}.req
	echo "destination_cluster_vip=${destination_cluster_vip}"       >>./${tr_job_reqid}.req
	# move request file to newRequests queue
	mv ./${tr_job_reqid}.req ${NEWREQUESTS_DIR}
	log "Request ${tr_job_reqid} has been created and corresponding request file ${tr_job_reqid}.req is moved to newRequests queue"
	log "Complete"
	#
	# return
	return 0
}

generate_reqfile "$@"
exit0
