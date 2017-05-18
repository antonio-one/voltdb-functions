#!/bin/bash

tmp_dir=/tmp/player/${this_uuid}
stream_log_out=${tmp_dir}/stream.log
stream_in=${tmp_dir}/in
stream_out=${tmp_dir}/out
scratch_dir=${tmp_dir}/scratch
staging_dir=${tmp_dir}/staging
bytes_per_reducer="512000000"
insert_type="into"
where_and_clause=""

if [ -z "$job_name" ]; then
	job_name="antonio-${this_uuid}"
fi

if [ -z "$job_user" ]; then
	job_user="antonio"
fi

if [ -z "$yarn_pool_name" ]; then
	yarn_pool_name="antonio"
fi

if [ -z "$stream_mapreduce_job_maps" ]; then
	stream_mapreduce_job_maps=20
fi

if [ -z "$stream_mapreduce_job_reduces" ]; then
	stream_mapreduce_job_reduces=1
fi

if [ -z $mapreduce_map_memory_mb ]; then
	mapreduce_map_memory_mb=4000
fi

if [ -z $mapreduce_map_java_opts ]; then
	mapreduce_map_java_opts="-Xmx3600m"
fi

if [ -z $mapreduce_map_memory_mb ]; then
	mapreduce_reduce_memory_mb=8000
fi

if [ -z $mapreduce_map_java_opts ]; then
	mapreduce_reduce_java_opts="-Xmx7200m"
fi
