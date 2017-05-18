#!/bin/bash

set -e

# This should theoretically import all the environment variables
sites_home=/somewhere/sites
source $sites_home/common/common-current/master

mkdir -p $working_directory
output=$working_directory/output
msts=$(date +%s)
sql_query="exec @Statistics IMPORTER 0;"

Logln INFO "Starting work. Your working directory is: $working_directory"

echo "$sql_query" | 
  sqlcmd --servers=$sqlcmd_servers --output-format=tab --output-skip-metadata | 
  sort -k2 -k3 -k5 | 
  grep -vi "Strict java memory checking is enabled" | 
  tee $output

while read line; do

	hostname=$(echo $line | awk '{print $3}')
	site=$(echo $line | awk '{printf $4}')
	importer_name=$(echo $line | awk '{print $5}')
	procedure=$(echo $line | awk '{print $6}')
	successes=$(echo $line | awk '{printf "%0.f",$7}')
	failures=$(echo $line | awk '{printf "%0.f",$8}')
	outstanding_requests=$(echo $line | awk '{printf "%0.f",9}')
	retries=$(echo $line | awk '{printf "%0.f",$10}')

echo -ne "
voltdb_statistics_importer_success_total{environment=\"$ENV\", importer=\"$importer_name\", host=\"$hostname\", site=\"$site\", procedure=\"$procedure\"} $successes
voltdb_statistics_importer_failures_total{environment=\"$ENV\", importer=\"$importer_name\", host=\"$hostname\", site=\"$site\", procedure=\"$procedure\"} $failures
voltdb_statistics_importer_outstanding_total{environment=\"$ENV\", importer=\"$importer_name\", host=\"$hostname\", site=\"$site\", procedure=\"$procedure\"} $outstanding_requests
voltdb_statistics_importer_retries_total{environment=\"$ENV\", importer=\"$importer_name\", host=\"$hostname\", site=\"$site\", procedure=\"$procedure\"} $retries
" >> $output.1

done < $output

Logln INFO "Pushing $output.1 to prometheus push gateway"

cat <<EOF | curl --data-binary @- $push_gateway_url/metrics/job/voltdb_statistics_importer/
	$(cat $output.1)
EOF

cat $output.1

Logln INFO "Cleaning up"
rm -rf $working_directory &>/dev/null || true
