#!/bin/bash

if [ $(to_lower $(uname)) == "darwin" ]; then
	HADOOP_LIB_LOCATION="/opt/hadoop-2.6.0/share/hadoop/tools/lib"
else
	HADOOP_LIB_LOCATION="$(dirname $(readlink -f /usr/bin/hadoop))/../lib/hadoop-mapreduce"
fi

if [ -z "${HADOOP_USER_NAME}" ]; then
	HADOOP_USER_NAME="antonio"
fi

function get_active_namenode
{
    webhdfs_namenode_url="http://${name_node_1}:50070/webhdfs/v1"

    # Test which namenode is active
    if curl -m 60 -i -f -N -I "$webhdfs_namenode_url/?op=LISTSTATUS" 2>&1 | grep -q "HTTP/1.1 200 OK" ; then
        # All ok
        NAMENODE=${name_node_1}
    else
        NAMENODE=${name_node_2}
    fi
}
