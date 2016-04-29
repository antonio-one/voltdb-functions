
#!/bin/bash
#
# This generates the voltdb deployment configuration file 
# A "mute" import configuration is useful when (a) a cluster is deployed with no classes loaded or (b) we temporarily want to stop the traffic witout pausing it
# Configuration structure documentation: https://docs.voltdb.com/UsingVoltDB/ConfigStructure.php#configsyntaxtab
#

USAGE="Usage ./create-config.sh consume groupid 40000
OR
./create-config.sh mute"

TYPE=${1}
GROUP_ID=${2}
SOCKET_TIMEOUT=${3}

if [[ -z ${GROUP_ID} ]]; then GROUP_ID=voltdb_default; fi
if [[ -z ${SOCKET_TIMEOUT} ]]; then SOCKET_TIMEOUT=60000; fi

#
# Blows up if variable(s) are bad                                
#

if [[ "${TYPE}" != "mute" && "${TYPE}" != "consume" ]]; then
  echo ${TYPE}
  echo -ne "Incorrect TYPE value. \n${USAGE}\n"
	exit 777
elif [[ "${TYPE}" = "mute" ]]; then
	:	# do nothing
elif [[ -z "$@" || -z "${TYPE}" || -z "${GROUP_ID}" ||  -z "${SOCKET_TIMEOUT}" ]]; then
	echo -ne "${USAGE}"
	exit 777
fi

# File locations
# Change this to configuration based
BASE_CONFIG_PATH=$(find . -name "config_base.xml")
IMPORT_CONFIG_PATH=/tmp/import_config.xml
CONFIG_PATH=$(find . -name "config.xml")
PROC_LIST_PATH=$(find . -name "procedures" | sort | head -n1)
BROKER_LIST=bivolt01:9092,bivolt02:9092,bivolt03:9092,bivolt04:9092

# Clean up

rm -f ${IMPORT_CONFIG_PATH} 2>/dev/null

# Create the import configuration xml part using the procedure-list
# ... make sure the procedure-list file is up to date

if [[ "${TYPE}" = "mute" ]]; then

	:	#echo "\t\t<!-- import configuration muted -->" > ${IMPORT_CONFIG_PATH}

else 

	while read LINE; do

		PROCEDURE=$(echo ${LINE,,} | sed 's/.java//g')
		EVENT_ID=$(echo ${LINE} | awk -F"_" '{print $2}') 

		PART_CONFIG='                                                                                     
		\t\t    <configuration module="kafkastream.jar" format="tsv" type="custom" enabled="true">    \n
		\t\t\t      <property name="brokers">'${BROKER_LIST}'</property>									            \n
		\t\t\t		<property name="groupid">'${GROUP_ID}'</property>										                \n
		\t\t\t      <property name="topics">event_'${EVENT_ID}'_log</property>                        \n
		\t\t\t      <property name="procedure">'${PROCEDURE}'</property>                              \n
		\t\t\t      <property name="socket.timeout.ms">'${SOCKET_TIMEOUT}'</property>                 \n
		\t\t    </configuration>																			                                \n'
	
		echo -e ${PART_CONFIG} >> ${IMPORT_CONFIG_PATH}  

	done < ${PROC_LIST_PATH}

fi

# Concatenate base and import to one configuration script
# Manual changes can be done to base config if needed

if [[ "${TYPE}" = "mute" ]]; then

CONFIG="<deployment>
"$(<${BASE_CONFIG_PATH})"
</deployment>"

else

CONFIG="<deployment>
"$(<${BASE_CONFIG_PATH})"
	<import>
"$(<${IMPORT_CONFIG_PATH})"
	</import>
</deployment>"

fi

echo -e "${CONFIG}" > ${CONFIG_PATH}

# End

echo
echo '[INFO]  :  configuration exported here: '${CONFIG_PATH}
echo
