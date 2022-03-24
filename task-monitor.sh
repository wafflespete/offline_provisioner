#! /bin/bash

## task-monitor.sh
## show user nice output of output, call after task manager only if not already running


function main () {


    tail -c+1 -f /tmp/prov_mon 2> /dev/null

}


main



