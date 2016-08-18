# !/bin/bash

#set -o xtrace

function wait_for_ping()
{
    ip=$1
    initial_time=$(date +%s)
    current_time=0
    timeout=360
    diff=$timeout

    while [ "$diff" -le "$timeout" ]; do
        ping -q -c 1 ${ip}

        rc=$?
        if [[ $rc -eq  1 ]]; then
            echo "Ping is replying now"
            break
        fi
        sleep 1
        current_time=$(date +%s)
        diff=$((current_time-initial_time))
    done

    return $rc
}

wait_for_ip $1
