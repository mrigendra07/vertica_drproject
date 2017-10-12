#!/bin/bash
#######################################################################
#                DR STARTUP SCRIPT v-1.0.0
#----------------------------------------------------------------------
# Author          : Bhupal Rai
# Release version : 1.0.0
# Updated by      : Bhupal Rai
# Last updated    : 2017 AUG 25
#----------------------------------------------------------------------
# Starts dr-replication daemon
#
#
#######################################################################
CONFIG_FILE=
ALL_ACTION=('start' 'stop' 'restart' 'status')
ACTION=
ALL_MODE=('normal' 'debug')
MODE=
#
# Heartbeat daemon script
HEARTBEAT="heartbeat.sh"

#######################################################################
# 			Functions
#######################################################################
function usage(){
echo "
NAME:
 $0

USAGE:
bash $0 [-h |--help] | [-c|--config  <config_file> -a|--action <action_to_perform> -m|--mode <exe_mode>]

DESCRIPTION:
This is a script to start|stop|restart|check status of dr-replication daemon

PARAMETERS:
 -h|--help                : show help
 -c|--config              : requires configuration file
 -a|--action              : requires action to perform
 -m|--mode				  : requires mode of execution

 - <config_file>          : configuration file for dr-replication
 - <action_to_perform>    : start|stop|restart|status
 - <exe_mode>			  : normal|debug

EXAMPLES:
bash $0 -c drconfig -a start -m normal
bash $0 --help
"
}


function exit_0(){
exit 0
}

function exit_1(){
exit 1
}


function usage_exit0(){
	usage
	exit 0
}


function usage_exit1(){
	usage
	exit 1
}


function usage_syntaxerr_exit1(){
	echo "Syntax error!"
	echo
	usage
	exit 1
}


function action_check(){
	action_cmd=${1}
	for action in  ${ALL_ACTION[@]};
	do
		if [ "${action^^}" = "${action_cmd^^}" ]; then
			#echo ${action};
			return
		fi
	done
	# action not found
	echo "action: ${action} not recognized."
	echo
	usage_exit1;
}


function mode_check(){
	mode_cmd=${1}
	for mode in  ${ALL_MODE[@]};
	do
		if [ "${mode^^}" = "${mode_cmd^^}" ]; then
			#echo ${mode};
			return
		fi
	done
	# mode not found
	echo "mode: ${mode_cmd} not supported."
	echo
	usage_exit1;
}


function validate_file(){
	#
	# Validate file.
	# It must exits, not empty and readable
	#
	vf_args=("$@")
	[ ${#vf_args[@]} -ne 1 ] && { echo "Argument error in ${FUNCNAME[0]}. Line: $LINENO ";  exit_1; }
	tmp_fname="${vf_args[0]}"

	[ ! -f "$tmp_fname" ] && { echo "'$tmp_fname' file not found."; exit_1; }
	if [ ! -s "$tmp_fname" ]; then
	        echo "$tmp_fname is empty."
	        exit_1
	fi
	f_type=$(file ${tmp_fname} | cut -d\  -f2)
	[[ ( "${f_type}" != "ASCII" ) && ( "${f_type}" != "Bourne-Again" ) && ( "${f_type}" != "POSIX" ) ]] && { echo "Cannot read ${1}, not a readable file."; exit_1; }
}


function initialize (){
	[ -z ${CONFIG_FILE} ] && { echo "Configuration file is not set"; usage_exit1; }
	[ -z ${ACTION} ] && { echo "Action is empty"; usage_exit1;}
	[ -z ${MODE} ] && { echo "Action is empty"; usage_exit1;}

	mkdir -p "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/tmp"
	#
	# heartbeat.sh file permission, 744
	# check here
}


function parse_opts {
	#
	# Parse arguments
	#
	params=( "$@" )
	[ ${#params[@]} -eq 0 ] && { usage_syntaxerr_exit1; }
	#
	# start parsing
	optspec=":c:a:m:-:h"
	while getopts "$optspec" opt; do
		case ${opt} in
			-)
				#
				# handle long opts/args
				#
				[ "${OPTARG}" = 'help' ] && { usage_exit0; }
				#
				# verify argument format
				if [ ! $(expr "${OPTARG}" : ".*[=].*") -gt 0 ] || [ "$(echo ${OPTARG} | cut -d '=' -f 2)" = "" ]; then
					echo "Invalid argument format"
					usage_syntaxerr_exit1
				fi
				case "${OPTARG}" in
					config=*)
						CONFIG_FILE=${OPTARG#*=}
						validate_file ${CONFIG_FILE}
						;;
					action=*)
						ACTION=${OPTARG#*=}
						ACTION=${ACTION,,}
						action_check ${ACTION}
						;;
					mode=*)
						MODE=${OPTARG#*=}
						MODE=${MODE,,}
						mode_check ${MODE}
						;;
					*)
						if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
							echo "Unknown option --${OPTARG}" >&2
							usage_exit1
						fi
						;;
				esac;;
			#
			# short args
			c)
				CONFIG_FILE="${OPTARG}"
				validate_file ${CONFIG_FILE}
				;;
			a)
				ACTION=${OPTARG#*=}
				ACTION=${ACTION,,}
				action_check ${ACTION}
				;;
			m)
				MODE=${OPTARG#*=}
				MODE=${MODE,,}
				mode_check ${MODE}
				;;
			h)
				usage_exit0
				;;
			*)
				echo '-'${OPTARG}" not a valid argument"
				usage_exit1
				;;
			:)
				echo "Option -${OPTARG} requires an argument"
				usage_exit1
				;;

			\?)
				usage_exit1
				;;
		esac
	done
}

#######################################################################
# 			script body
#######################################################################
args=( "$@" )
parse_opts ${args[@]}
initialize
#
# perform action
#
EX_MODE=
if [ "${MODE}" = "debug" ]; then
        EX_MODE="-x"
fi
case "${ACTION}" in
        start)
                /bin/bash ${EX_MODE} ${HEARTBEAT} ${CONFIG_FILE} ${MODE}
                ;;
#        stop)
#               stop
#               ;;
        *)
            echo "Action ${ACTION} not implemented yet. Exiting."
            exit_0
esac
