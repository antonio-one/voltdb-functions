#!/bin/bash

START_CMD=${1,,}
USAGE="./start-cluster.sh create|recover"

# Blows up if variable(s) are bad                                

if [[ "${START_CMD}" != "create" && "${START_CMD}" != "recover" ]]; then
    echo "This was gonna be the bomb... but it isn't anymore. ${USAGE}"
    exit 777
fi

# Prepare for action

source $CORE_PROPERTIES
source $CORE_FUNCTIONS
source $VOLTRC

echo "" > log/volt.log 2>/dev/null

# runStartupConfig
getNodeInfo master		# exports MASTER_HOST
getNodeInfo internalip	# exports INTERNAL_IP
getNodeInfo externalip  # exports EXTERNAL_IP

# Do that thing

START_CLUSTER_LOG=/tmp/start-cluster-${START_CMD}.out

if [[ "${START_CMD}" == "create" ]]; then

	nohup voltdb create						\
		--deployment=${CONFIG_PATH}			\
		--host=${MASTER_HOST}				\
		--client=${CLIENT_PORT}				\
		--internalinterface=${INTERNAL_IP}  \
		--externalinterface=${EXTERNAL_IP}  \
		--license=${LICENSE_PATH} > ${START_CLUSTER_LOG} 2>&1 &

elif [[ "${START_CMD}" == "recover" ]]; then

	nohup voltdb recover					\
		--deployment=${CONFIG_PATH}			\
		--host=${MASTER_HOST}				\
		--license=${LICENSE_PATH} > ${START_CLUSTER_LOG} 2>&1 &

else

	echo "This doesn't make any sense"
	exit 777

fi

tail -f ${START_CLUSTER_LOG} -f -n100 log/volt.log
