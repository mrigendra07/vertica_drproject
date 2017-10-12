#!/bin/bash
#######################################################################
# 					Database
#----------------------------------------------------------------------
# Database related actions are done here.
# All the query strings required for the application may be moved to
# another file.
#
#######################################################################
source ${BASE_DIR}/status_log_handler.sh
# Global quries
VTKA_SQL_SETROLEALL='SET ROLE ALL'
VTKA_SQL_GET_NODES="SELECT NODE_NAME FROM DBMONITOR.CLUSTER_INFO ORDER BY NODE_NAME"
VTKA_SQL_GET_HOSTS="SELECT HOST_NAME FROM DBMONITOR.CLUSTER_INFO ORDER BY NODE_NAME"
#
# vsql
if [ -f ${VSQLBIN} ]; then
	VSQLBIN='/opt/vertica/bin/vsql'
fi

#######################################################################
# 			functions
#######################################################################
function check_vsql(){
    if hash ${VSQLBIN} 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

function execute_vtka_query(){
	if ! check_vsql; then
		return 1;
	fi
	host_name="${1}"
	db_name="${2}"
	port="${3}"
	user_name="${4}"
	password="${5}"
	query="${6}"
	query="${VTKA_SQL_SETROLEALL}; ${query};"
	#
	# execute query
	QUERY_OUTPUT_F="${DUMMY_ABS_DIR}/._${host_name}."$(date +'%Y%m%d%H%M%S%3N')
	> ${QUERY_OUTPUT_F}
	${VSQLBIN} -t -A -h ${host_name} -d ${db_name} -p ${port} -U ${user_name} -w ${password} -C -c "${query}" >>${QUERY_OUTPUT_F}
	exit_code=$?
	#
	# return
	return ${exit_code}

}

function get_vtka_nodes_hosts(){
	#
	# Returns cluster information table data
	#
	# Parameters: cluster_vip, port, db_name
	if [ "$#" -ne 6 ]; then
		log ""  "6 parameters expected got $#"
		return 1
	fi
	_cluster_vip="${1}"
	_db_name="${2}"
	_port="${3}"
	_user_name="${4}"
	_encpwd="${5}"
	if [ "${6}" = "nodes" ]; then
		_query=${VTKA_SQL_GET_NODES}
	elif [ "${6}" = "hosts" ]; then
		_query=${VTKA_SQL_GET_HOSTS}
	else
		log "Unknown parameter '${6}' in module ${FUNCNAME[0]}"
		return 1
	fi
	# execute query
	execute_vtka_query "${_cluster_vip}" "${_db_name}" "${_port}" "${_user_name}" "${_encpwd}" "${_query}"
	#read EX_CODE < ${QUERY_EXEC_EXCODE}
	if [ $? -ne 0 ]; then
		log "Error while executing query. Query: ${VTKA_SQL_GET_NODES}. View error file for more detail ${STDERRFILE}"
		return 1
	fi
	#
	# append output to array
	_nodes=()
	OLD_IFS=$IFS
	IFS=$'\n'
	while read -r c_line; do
		[ -z "${c_line}" ] && continue
		_nodes+=("${c_line}")
	done <${QUERY_OUTPUT_F}
	IFS=${OLD_IFS}
	#
	# remove tmp file
	###| Note: make arrangement to remove tmp file in execute_vtka_query module |###
	#[ -f "${QUERY_OUTPUT_F}" ] && rm -f "${QUERY_OUTPUT_F}"
	#
	# return
	echo ${_nodes[*]}
	return 0
}
