#!/bin/bash

set -e

cd "$(dirname "$0")"
source ../master


output_dir=/tmp/$(create_uuid)
mkdir -p $output_dir 2>/dev/null
output_exa=$output_dir/output_exa
output_pro=$output_dir/output_pro
touch $output_exa
touch $output_pro

fLog INFO "Your working directory is $output_dir"

while read line;
do

	topic=$(echo $line | awk '{print $1}')
	group=$(echo $line | awk '{print $2}')

	topic_tmp=$output_dir/topic_tmp
	$kafka_bin/kafka-run-class.sh kafka.tools.ConsumerOffsetChecker --zookeeper $kafka_zookeeper --group $group --topic $topic > $topic_tmp

	declare i exception=$(cat $topic_tmp | egrep -i "NoNodeException|Empty.head" | wc -l)

	if [[ "$exception" -eq "0" ]]; then
		fLog INFO "Writing $topic metrics to $output_exa"
		cat $topic_tmp |
			tail -n+2 |
				awk -v voltdb_timestamp="$voltdb_timestamp" '{print $1"\t"$2"\t"$3"\t"$4"\t"$5"\t"$6"\t"$7"\t"voltdb_timestamp}' |
					tee -a $output_exa
	fi

done < ../config/topic-group.txt

# push the avg lag from all partitions per topic to prometheus
while read line; do

	topic=$(echo $line | awk '{print $2}')
	pid=$(echo $line | awk '{print $3}')
	lag=$(echo $line | awk '{printf "%0.f",$6}')
	echo "kafka_consumer_lag{environment=\"$ENV\", group=\"$group\", topic=\"$topic\", pid=\"$pid\"} $lag" >> $output_pro

done < $output_exa

cat $output_pro

cat <<EOF | curl --data-binary @- $push_gateway_url/metrics/job/kafka_consumer_offset/
	$(cat $output_pro)
EOF

rm -rf $output_dir &>/dev/null || true
