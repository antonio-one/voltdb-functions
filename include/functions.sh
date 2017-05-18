#!/bin/bash

### generic
function create_uuid() {

    local N B C='89ab'

    for (( N=0; N < 16; ++N ))
    do
        B=$(( $RANDOM%256 ))

        case $N in
            6)
                printf '4%x' $(( B%16 ))
                ;;
            8)
                printf '%c%x' ${C:$RANDOM%${#C}:1} $(( B%16 ))
                ;;
            3 | 5 | 7 | 9)
                printf '%02x-' $B
                ;;
            *)
                printf '%02x' $B
                ;;
        esac
    done

    echo
}	# End create_uuid

this_uuid=$(create_uuid | sed 's/-//g')
this_uuid_dir=/fjord/tmp/$this_uuid

function to_upper() {
    echo "${1}" | awk '{print toupper($0)}'
}	# End to_upper

function to_lower() {
    echo "${1}" | awk '{print tolower($0)}'
}  # End to_lower

function remove_whitespace() {
    echo "${1}" | sed 's/ //g'
}  # End remove_whitespace

if [ $(to_lower $(uname)) == "darwin" ]; then
  date_cmd="gdate"
else
  date_cmd="date"
fi

today_str=$(eval "$date_cmd +%Y-%m-%d")
today_int=$(eval "$date_cmd +%Y%m%d")
yesterday_str=$(eval "$date_cmd -d "yesterday" +%Y-%m-%d")
yesterday_int=$(eval "$date_cmd -d "yesterday" +%Y%m%d")
current_msts=$(eval "$date_cmd --date $($date_cmd +%Y-%m-%dT%H:%M:%S) +%s")000
current_msts_minute_acc=$(eval "$date_cmd --date $($date_cmd +%Y-%m-%dT%H:%M:00) +%s")000
voltdb_timestamp=$(eval "$date_cmd +\"%Y-%m-%d %H:%M:%S\"").000000
current_timestamp=$(eval "$date_cmd +\"%Y-%m-%d %H:%M:%S\"")
