#!/bin/bash

######### DB ###########

db_connection=
db_cmd_dir=
db_home=
db_retry=3
db_retry_delay=10

######### Hadoop #######
name_node_1=
name_node_2=

######### Voltdb #######

voltdb_cluster_domain=
voltdb_path=/opt/voltdb-ent/voltdb-ent-current
kafkaloader_host_url=http://kafkaloader:9001

######### Hive ############

export hive_jdbc_host="hive:10000"
export hive_jdbc_user="antonio"
export hive_jdbc_db="antonio"

######### Kafka ##########

export kafka_bin=/opt/kafka/bin
export kafka_zookeeper=zk01:2181,zk02:2181,zk03:2181/kafka
export kafka_broker=br01:9092,br02:9092,br03:9092
export group_id=nerve.prod.4

######### Kafka BETA ##########

export kafka10_zookeeper=zk04:2181,zk05:2181,zk06:2181/kafka
export kafka10_broker=br111:9092,br112:9092,br113:9092

######### Prometheus #########

export push_gateway_url=http://prometheus:9091
export prometheus_url=http://prometheus:9090

######### Yarn #############

export job_history_server_url="http://jobhistoryserver:19888"

######### Graphite #############

graphite_server=
graphite_port=2003

######### MySql #############
mysql_host=
