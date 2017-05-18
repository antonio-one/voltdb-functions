#!/bin/bash

set -e

cd "$(dirname "$0")"
source ../master

source_path=../config/purge-list.txt

while read line
do

  table_name=$(echo $line | awk '{print $1}')
  purge_column=$(echo $line | awk '{print $2}')
  unit=$(echo $line | awk '{print $3}')
  value=$(echo $line | awk '{print $4}')

  if [[ $purge_column == "dt" ]]
  then
    value="'$(date --date="$value days ago" +"%Y-%m-%d")'"
  elif [[ $purge_column == "updated_msts" ]]
  then
    value=$(date --date="$(date --date="$value days ago" +"%Y-%m-%d %H:00:00")" +%s000)
  else
    fLog ERROR "Unrecognised purge_column in $source_path"
  fi

  purge_cmd="DELETE FROM $table_name WHERE $purge_column<=$value;"
  exec_voltdb "$purge_cmd"

done < $source_path
