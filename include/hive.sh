#!/bin/bash

query_hive () {

    local sql_input="${1}"

    if [ -z "$2" ]; then
        local  __resultvar_stdout=__resultvar_stdout
    else
        local  __resultvar_stdout=$2
    fi

    if [ -z "$3" ]; then
        local  __resultvar_stderr=__resultvar_stderr
    else
        local  __resultvar_stderr=$3
    fi

    fLog INFO "Your hive working directory is $this_uuid_dir"
    rm -rf $this_uuid_dir 2>/dev/null
    mkdir -p $this_uuid_dir 2>/dev/null
    local sql_query_path=$this_uuid_dir/sql
    touch $sql_query_path 2>/dev/null

    local __file_stderr="$this_uuid_dir/executehive.stderr.$$"
    local __file_stdout="$this_uuid_dir/executehive.stdout.$$"
    local __file_failure="$this_uuid_dir/executehive.failure.$$"
    local __file_tmp="$this_uuid_dir/executehive.tmp.$$"

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

    command="beeline -ujdbc:hive2://$hive_jdbc_host -n$hive_jdbc_user --outputformat=tsv2 --showHeader=false --silent=true -f \"$sql_query_path\""

    while read -r line
    do
        echo "$line"
    done < <( ($command >$__file_stdout || touch $__file_failure) 2>&1 | tee $__file_stderr )

    #capture actual command (hive) output
    local __stdout=$(cat $__file_stdout|grep -Ev "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3} (INFO|WARN)" | grep -Ev '^\. \. \. \. \. \. \. \. \. \. \. \. \. \. \. \. \. \. \. \. \. \. \.> .*' | grep -Ev "^$" | grep -Ev "^0: jdbc:hive2://")
    local __stderr=$(cat $__file_stderr)

    #set variables to hold results
    if [[ "$__resultvar_stdout" ]]; then
        eval $__resultvar_stdout='$__stdout'
        eval $__resultvar_stderr='$__stderr'
    else
        echo -e "$__stdout" #only used if calling function in old RESULT=`myfunc` style
    fi

    rm -rf $this_uuid_dir >/dev/null

}
