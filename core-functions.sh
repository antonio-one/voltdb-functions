#!/bin/bash

THIS_UUID=$(cat /proc/sys/kernel/random/uuid | sed 's/-//g')

BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BROWN_ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_GRAY='\033[0;37m'
DARK_GRAY='\033[1;30m'
LIGHT_RED='\033[1;31m'
LIGHT_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHT_BLUE='\033[1;34m'
LIGHT_PURPLE='\033[1;35m'
LIGHT_CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

prompt() {

    local _MSG="${1}"

    if [[ -z "${_MSG}" ]]; then
        _MSG="Continue to the next step? y(es) | N(o) "
    else
        _MSG="Continue with "${_MSG}"? y(es) | N(o) "
    fi

    printf "${CYAN}" && read -p "${_MSG}" RESPONSE && printf "${NC}"
    echo
    case "${RESPONSE,,}" in
        y|yes)
            : # continue
			;;
        *)
            Log MOUSE "Are you a man or a ..."
            exit 777
            ;;
    esac
}

Log() {

	local _TYPE="${1^^}"
	local _MSG="${2}"
	local _WITH_PROMPT="${3}"

	if [[ "${_WITH_PROMPT}" = "--with-prompt" ]]; then 
		prompt "${_MSG}" 
	fi

	case "${_TYPE}" in
	INFO)
		printf "$(date -u) ${GREEN}[${_TYPE}] ""${_MSG}""${NC}\n" 1>&2
		;;
	DEBUG)
		printf "$(date -u) ${LIGHT_BLUE}[${_TYPE}] ""${_MSG}""${NC}\n" 1>&2
		;;
	WARN)
		printf "$(date -u) ${BROWN_ORANGE}[${_TYPE}] ""${_MSG}""${NC}\n" 1>&2
		;;
	ERROR)
		printf "$(date -u) ${RED}[${_TYPE}] ""${_MSG}""${NC}\n" 1>&2
		exit 1
		;;
	*)
		printf "$(date -u) ${WHITE}[${_TYPE}] ""${_MSG}""${NC}\n" 1>&2
		;;
	esac
}

getNodeInfo() {

	local _INFO="${1,,}"
	local _HOSTS=$(find . -name hosts.csv) # get this from config instead
	
	case ${_INFO} in
		master)
		    while read LINE; do
          		NODE_TYPE=$(awk -F, '{print $4}' <<< ${LINE})
			if [[ "${NODE_TYPE,,}" == "master" ]]; then
				export MASTER_HOST=$(awk -F, '{print $2}' <<< ${LINE})
				Log DEBUG "MASTER_HOST=${MASTER_HOST}"
          		fi
        		done < ${_HOSTS}
		    	;;

		internalip)
			while read LINE; do
		        NODE_HOSTNAME=$(awk -F, '{print $1}' <<< ${LINE})
		        if [[ "${NODE_HOSTNAME}" == "${HOSTNAME}" ]]; then
          			export INTERNAL_IP=$(awk -F, '{print $2}' <<< ${LINE})
				Log DEBUG "INTERNAL_IP=${INTERNAL_IP}"
			fi  
	      		done < ${_HOSTS}
			;;

		externalip)
      			while read LINE; do
        		NODE_HOSTNAME=$(awk -F, '{print $1}' <<< ${LINE})
		        if [[ "${NODE_HOSTNAME}" == "${HOSTNAME}" ]]; then
		        	_export EXTERNAL_IP=$(awk -F, '{print $3}' <<< ${LINE})
				Log DEBUG "EXTERNAL_IP=${EXTERNAL_IP}"
			fi  
			done < ${_HOSTS}
			;;

		download|upload|deploy)
		  # get this from config in the future
			local _RANDOM_NODE=bivolt0$(shuf -i 1-1 -n 1).yourdomain.com
			eval "export ${_INFO^^}_HOST=${_RANDOM_NODE}"
			Log DEBUG "${_INFO^^}_HOST=${_RANDOM_NODE}"

			local _IP=$(host ${_RANDOM_NODE} | awk '{print $4}')
			eval "export ${_INFO^^}_HOST_IP=${_IP}"
			Log DEBUG "${_INFO^^}_HOST_IP=${_IP}"
			;;

	esac

}

saveSnapshotAndDie() {

	getNodeInfo deploy
	SNAPSHOT_NAME=SNAPSHOT_$(date +"%Y%m%d%H%M%S")
	ssh -t -t ${DEPLOY_HOST} << EOF
	voltadmin pause && \
	voltadmin save --blocking /voltdata/snapshots ${SNAPSHOT_NAME} -H ${DEPLOY_HOST_IP} && \
	voltadmin shutdown -H ${DEPLOY_HOST_IP}
	exit
EOF
}

saveSnapshotAndLive() {

	getNodeInfo deploy
	SNAPSHOT_NAME=SNAPSHOT_$(date +"%Y%m%d%H%M%S")
	Log INFO "Starting snapshot /voltdata/snapshots/${SNAPSHOT_NAME}"
	ssh -t -t ${DEPLOY_HOST}  << EOF
	voltadmin pause -H ${DEPLOY_HOST_IP} && \
	voltadmin save --blocking /voltdata/snapshots ${SNAPSHOT_NAME} -H ${DEPLOY_HOST_IP} && \
	voltadmin resume -H ${DEPLOY_HOST_IP}
	exit
EOF
}

executeSQL() {
  # work in progress
	SQL_CMD="{1,,}"
	getNodeInfo deploy
	local _SQL_CMD_PATH=/tmp/${THIS_UUID}.sql

	echo -ne "${SQL_CMD}" > ${_SQL_CMD_PATH}
	scp ${_SQL_CMD_PATH} ${DEPLOY_HOST}:${_SQL_CMD_PATH}
	ssh -t -t "/opt/voltdb/sqlcmd --servers=${SQLCMD_SERVERS} < ${_SQL_CMD_PATH}"

}

# Build some sudo stuff for this function ...
runStartupConfig() {

    swapoff -a

    for f in /sys/kernel/mm/*transparent_hugepage/enabled; do
        if test -f $f; then
            echo never > $f
        fi
    done

    for f in /sys/kernel/mm/*transparent_hugepage/defrag; do
        if test -f $f; then
            echo never > $f
        fi
    done

    sysctl -w vm.overcommit_memory=1

    sysctl -w vm.max_map_count=1048576

    ethtool -K eth0 tso off
    ethtool -K eth0 gro off

    ethtool -K eth1 tso off
    ethtool -K eth1 gro off

}

downloadCatalog() {

	local _CATALOG_TYPE="${1,,}"
	getNodeInfo download	# exports DOWNLOAD_HOST

	if [[ "${_CATALOG_TYPE}" =~ ^(tables|columns|procedures)$ ]]; then
		URL='http://'"${DOWNLOAD_HOST}"':8080/api/1.0/?Procedure=@SystemCatalog&Parameters=["'${_CATALOG_TYPE}'"]'	
		OUT=/tmp/voltdb_${_CATALOG_TYPE,,}_${THIS_UUID}.json
		rm -f ${OUT} 2>/dev/null
		wget ${URL} --output-document=${OUT}
		CMD="export ${_CATALOG_TYPE^^}_JSON_OUT=${OUT}"
		Log DEBUG "${CMD}"
		eval "${CMD}"
		
	else
		Log ERROR "unrecognised input parameter"
	fi
}

getColumns() {

	local _TABLE_NAME="${1,,}"

	downloadCatalog tables
	downloadCatalog columns

	local -i MAX_ELEMENT_COUNT=$( jq '.results[0].schema' ${COLUMNS_JSON_OUT} | grep -i name | wc -l )
	local -i MAX_COLUMN_COUNT=$(jq '.results[0].data[]' ${COLUMNS_JSON_OUT} | grep "\[" | wc -l)

	for (( i=0; i<${MAX_ELEMENT_COUNT}; i++ )); do

    	IS_TABLE_NAME=$( jq '.results[0].schema['${i}'] | contains ({"name":"TABLE_NAME"})' ${COLUMNS_JSON_OUT} )
    	IS_COLUMN_NAME=$( jq '.results[0].schema['${i}'] | contains ({"name":"COLUMN_NAME"})' ${COLUMNS_JSON_OUT} )
    	IS_TYPE_NAME=$( jq '.results[0].schema['${i}'] | contains ({"name":"TYPE_NAME"})' ${COLUMNS_JSON_OUT} )
    	IS_COLUMN_SIZE=$( jq '.results[0].schema['${i}'] | contains ({"name":"COLUMN_SIZE"})' ${COLUMNS_JSON_OUT} )

    	if [ "${IS_TABLE_NAME,,}" = "true" ]; then
        	TABLE_NAME_POSITION=$i
    	elif [ "${IS_COLUMN_NAME,,}" = "true" ]; then
        	COLUMN_NAME_POSITION=$i
    	elif [ "${IS_TYPE_NAME,,}" = "true" ]; then
        	TYPE_NAME_POSITION=$i
    	elif [ "${IS_COLUMN_SIZE,,}" = "true" ]; then
        	COLUMN_SIZE_POSITION=$i
    	fi

	done

	Log INFO "Standby, this is not super fast"
	COLUMNS=""
	for (( i=0; i<${MAX_COLUMN_COUNT}; i++ )); do
		ROW_TABLE_NAME=$( jq -r '.results[0].data['$i']['${TABLE_NAME_POSITION}']' ${COLUMNS_JSON_OUT} )
		if [[ "${_TABLE_NAME,,}" == "${ROW_TABLE_NAME,,}" ]]; then
			NEW_COLUMN=$( jq -r '.results[0].data['$i']['${COLUMN_NAME_POSITION}']' ${COLUMNS_JSON_OUT} )
			COLUMNS=${COLUMNS,,}${NEW_COLUMN,,}","
		fi

	done

	RESULT="${COLUMNS::-1}"
}


getTables() {

	downloadCatalog tables

  	local -i _MAX_ELEMENT_COUNT=$( jq '.results[0].schema' ${TABLES_JSON_OUT} | grep -i name | wc -l )
	local -i _MAX_COLUMN_COUNT=$(jq '.results[0].data[]' ${TABLES_JSON_OUT} | grep "\[" | wc -l)

  	for (( i=0; i<${_MAX_ELEMENT_COUNT}; i++ )); do
    		local _IS_TABLE_NAME=$( jq '.results[0].schema['${i}'] | contains ({"name":"TABLE_NAME"})' ${TABLES_JSON_OUT} )
		
		if [ "${_IS_TABLE_NAME,,}" = "true" ]; then
            		local _TABLE_NAME_POSITION=$i
		fi
	done

	export TABLE_LIST=$(jq -r '.results[].data[]['${_TABLE_NAME_POSITION}']' ${TABLES_JSON_OUT})

}

getTableInfo() {

	local _TABLE_NAME="${1,,}"
	downloadCatalog tables

	Log INFO "Looking for $_TABLE_NAME info ..."

	local -i _MAX_ELEMENT_COUNT=$(( $(jq -r '.results[0].schema[].name' ${TABLES_JSON_OUT} | wc -l) - 1 ))
	local -i _MAX_TABLE_COUNT=1000
	
	# Get table name and partition info
	# Get the position of the "table_name" and the "remarks" from the json schema

	for i in $(seq 0 ${_MAX_ELEMENT_COUNT}); do

    	local _IS_TABLE_NAME=$( jq '.results[0].schema['${i}'] | contains ({"name":"TABLE_NAME"})' ${TABLES_JSON_OUT} )
	    local _IS_REMARK=$( jq '.results[0].schema['${i}'] | contains ({"name":"REMARKS"})' ${TABLES_JSON_OUT} )

	    if [ "${_IS_TABLE_NAME,,}" = "true" ]; then
    	    _TABLE_NAME_POSITION=$i
    	fi

	if [ "${_IS_REMARK,,}" = "true" ]; then
        	_REMARKS_POSITION=$i
    	fi

	done
	
	# Find the table and extract whatever info is required

	for i in $(seq 0 ${_MAX_TABLE_COUNT}); do

    local _JSON_TABLE_NAME=$(jq -r '.results[0].data['$i']['${_TABLE_NAME_POSITION}']' ${TABLES_JSON_OUT})

	if [ "${_JSON_TABLE_NAME,,}" = "${_TABLE_NAME}" ]; then
		local _REMARK=$(jq -r '.results[0].data['$i']['${_REMARKS_POSITION}']' ${TABLES_JSON_OUT})
		Log DEBUG "_REMARK=$_REMARK"
		local _JAVA_FILE_PATH=$(readlink -f $(find ./../ -name "${_TABLE_NAME}_insert.java")) # this works only for insert procedures
		Log DEBUG "_JAVA_FILE_PATH=$_JAVA_FILE_PATH"
		local _START_POSITION=$(( $(grep -ni "public VoltTable" ${_JAVA_FILE_PATH} | awk -F":" '{print $1}') + 1 ))
		Log DEBUG "_START_POSITION=$_START_POSITION"
		local _END_POSITION=$(( $(grep -ni "throws VoltAbortException" ${_JAVA_FILE_PATH} | awk -F":" '{print $1}') - 2 ))
		Log DEBUG "_END_POSITION=$_END_POSITION"
		export PARTITION_COLUMN=$(echo ${_REMARK} | jq -r '.partitionColumn')
		Log DEBUG "PARTITION_COLUMN=$PARTITION_COLUMN"
		export ORDINAL_POSITION=$(( $(cat ${_JAVA_FILE_PATH} | awk 'NR >= '${_START_POSITION}' && NR < '${_END_POSITION} | grep -ni " ${PARTITION_COLUMN,,}," | awk -F":" '{print $1}') - 1 ))
		Log DEBUG "ORDINAL_POSITION=$ORDINAL_POSITION"
		export TABLE_NAME=$_JSON_TABLE_NAME
	else
		:	
	fi

	done

}
