#!/bin/bash

export voltdb_bin=${voltdb_path}/bin
export voltdb_home=${voltdb_path}
export voltdb_tools=${voltdb_path}/tools
export voltdb_root=/fjord/voltroot

PATH="$PATH:$voltdb_bin"
export PATH

export VOLTDB_CLASSPATH="$CLASSPATH:${voltdb_path}/voltdb/*:${voltdb_path}/lib/*:$exa_home/*"
export voltdb_classpath=$VOLTDB_CLASSPATH
export voltdb_heapmax="8192"
export voltdb_client_port="21212"
export voltdb_admin_port="21211"

export voltdb_host_file=$(find $nerve_common -name host.${ENV}.csv)
export voltdb_hosts=$(awk -F',' '{print $1}' $voltdb_host_file | tail -n+2)
export voltdb_node_count=$(( $(cat $voltdb_host_file | wc -l) - 1 ))
sqlcmd_servers=$(awk -F',' '{print $3}' $voltdb_host_file | tail -n+2 | tr '\n' ',')
export sqlcmd_servers=${sqlcmd_servers:0:${#sqlcmd_servers}-1}
export voltdb_deploy_home=$nerve_common/voltdb-deploy

export voltdb_client_jar=voltdbclient-6.9.4.jar
export voltdb_hadoop_jar=voltdb-hadoop-1.1-SNAPSHOT.jar
export voltdb_hive_jar=voltdb-hive-1.1-SNAPSHOT.jar

# VoltDB hive-storage-handler variables for external tables
# Not global variables
voltdb_import_batch_size=20000
voltdb_import_client_timeout=240000

voltdb_export_batch_size=8000
voltdb_export_max_errors=1000
voltdb_export_client_timeout=2400000

function get_voltdb_init_config() {

	export voltdb_init_config_path=$(find $nerve_common -name voltdb.config.init.${ENV}.xml)
	fLog DEBUG "voltdb_init_config_path=$voltdb_init_config_path"

} # End get_voltdb_init_config

function get_voltdb_config_path() {

	local _type="${1}"

	export voltdb_config_path=$(find $nerve_common -name voltdb.config.${_type}.${ENV}.xml)
	fLog DEBUG "voltdb_config_path=$voltdb_config_path"

} # End get_voltdb_config_path

function get_voltdb_node_info() {

  local _info=$(to_lower ${1})

	case $_info in
		master)
		    while read _line; do
        	local _node_type=$(awk -F, '{print $4}' <<< $_line)
					if [[ "$_node_type" == "master" ]]; then
            export master_host=$(awk -F, '{print $2}' <<< $_line)
						fLog DEBUG "master_host=$master_host"
					fi
		    done < ${voltdb_host_file}
			;;

		internal_ip)
			while read _line; do
        local _node_hostname=$(awk -F, '{print $1}' <<< $_line)
        if [[ "$_node_hostname" == "$HOSTNAME" ]]; then
          export internal_ip=$(awk -F, '{print $2}' <<< $_line)
					fLog DEBUG "internal_ip=$internal_ip"
				fi
      done < ${voltdb_host_file}
			;;

		external_ip)
      while read _line; do
        local _node_hostname=$(awk -F, '{print $1}' <<< ${_line})
        if [[ "$_node_hostname" == "$HOSTNAME" ]]; then
        	export external_ip=$(awk -F, '{print $3}' <<< $_line)
					fLog DEBUG "external_ip=$external_ip"
				fi
      done < ${voltdb_host_file}
			;;

		download|upload|deploy|query|random)
			local _random_node=$(cat $voltdb_host_file | grep -v hostname | shuf -n1 | awk -F',' '{print $1}')
			eval "export $(to_lower ${_info})_host=${_random_node}.${voltdb_cluster_domain}"
			fLog DEBUG "$(to_lower ${_info})_host=${_random_node}.${voltdb_cluster_domain}"
			local _ip=$(cat ${voltdb_host_file} | grep -i ${_random_node} | awk -F, '{print $3}')
			eval "export $(to_lower ${_info})_host_ip=${_ip}"
			fLog DEBUG "$(to_lower ${_info})_host_ip=${_ip}"
			;;

		*)
			fLog ERROR "No no no no no no no no no no no no there's no limit no no ... you know how this goes."
			;;

	esac

}	# End get_voltdb_node_info

function get_random_host_ip() {

	get_voltdb_node_info random &>/dev/null
	echo $random_host_ip

} # End get_random_host_ip

function query_voltdb() {

	local sql_input="$1"

	working_dir=/fjord/tmp/$(create_uuid)
	rm -rf $working_dir 2>/dev/null
	mkdir -p $working_dir 2>/dev/null
	local sql_query_path=$working_dir/sql
	touch $sql_query_path 2>/dev/null

	# Copy or write the file containing the query we want to execute
	case "$sql_input" in
		*.sql)
			if [ -r $sql_input ]; then
					cp $sql_input $sql_query_path
			fi
			;;
		*)
			echo -ne "$sql_input" > "$sql_query_path"
			;;
	esac

	cd $voltdb_bin
	sqlcmd --servers=$sqlcmd_servers --port=$voltdb_client_port --query-timeout=600000 --output-skip-metadata < "$sql_query_path" | grep -vi "strict java memory"

	rm -rf $working_dir >/dev/null

}	#	End query_voltdb

function exec_voltdb() {

	local sql_input="$1"

	working_dir=/fjord/tmp/$(create_uuid)
	rm -rf $working_dir 2>/dev/null
	mkdir -p $working_dir 2>/dev/null
	local sql_query_path=$working_dir/sql
	touch $sql_query_path 2>/dev/null

	# Copy or write the file containing the query we want to execute
	case "$sql_input" in
		*.sql)
			if [ -r $sql_input ]; then
					cp $sql_input $sql_query_path
			fi
			;;
		*)
			echo -ne "$sql_input" > "$sql_query_path"
			;;
	esac

	sqlcmd --servers=$sqlcmd_servers --port=$voltdb_admin_port --query-timeout=600000  < "$sql_query_path" | grep -vi "strict java memory"

	rm -rf $working_dir >/dev/null

}	#	End exec_voltdb
