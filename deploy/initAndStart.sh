#!/bin/bash +x

pushd `dirname ${BASH_SOURCE[0]}` > /dev/null
SCRIPTPATH=`pwd -P`
popd > /dev/null

source $SCRIPTPATH/../master.com

get_voltdb_node_info master	# exports master_host
get_voltdb_node_info internal_ip	# exports internal_ip
get_voltdb_node_info external_ip  # exports external_ip
get_voltdb_init_config
licence_path=$(find $voltdb_root/ -name King$(to_upper ${ENV})-2017-07-31-v2.xml)
fLog DEBUG "licence_path=$licence_path"

cmd="export VOLTDB_HEAPMAX=\"$voltdb_heapmax\";

$voltdb_bin/voltdb create --pause --force --deployment=$voltdb_init_config_path --host=$master_host --client=$voltdb_client_port --internalinterface=$internal_ip --externalinterface=$external_ip --license=$licence_path --background
"
# To re-enable the below, insert it inside the cmd quotes above before the voltdb create command.
# export VOLTDB_OPTS=\"-Xloggc:/dev/shm/voltdb.gc.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintHeapAtGC -XX:+PrintTenuringDistribution -XX:PrintFLSStatistics=1 -XX:+PrintGCApplicationConcurrentTime -XX:+PrintGCApplicationStoppedTime -XX:+PrintTLAB -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=2 -XX:GCLogFileSize=100M\";


echo -ne "${cmd}"

sudo -u antonio -H bash -c "${cmd}"

# GC
# -Xloggc:/dev/shm/voltdb.gc.log
# -XX:+PrintGCDetails
# -XX:+PrintGCDateStamps
# -XX:+PrintHeapAtGC
# -XX:+PrintTenuringDistribution
# -XX:PrintFLSStatistics=1
# -XX:+PrintGCApplicationConcurrentTime
# -XX:+PrintGCApplicationStoppedTime
# -XX:+PrintTLAB
# -XX:+UseGCLogFileRotation
# -XX:NumberOfGCLogFiles=2
# -XX:GCLogFileSize=100M

# FlightRecorder (requested by VoltDB)
# -XX:+UnlockDiagnosticVMOptions
# -XX:+DebugNonSafepoints
# -XX:+UnlockCommercialFeatures
# -XX:+FlightRecorder
# -XX:FlightRecorderOptions=maxage=1d,disk=true,threadbuffersize=128k,globalbuffersize=32m
