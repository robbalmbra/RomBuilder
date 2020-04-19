#!/bin/bash

# Logs to buildkite progress of bacon build every N seconds

LOG_FILE=$1
SLEEP_WAIT=$2

while [ 1 ]
do
  last_line=$(tail -n 1 $LOG_FILE)
  
  # Exit if build is marked as complete
  if [ $last_line -eq "BUILD_COMPLETE" ]; then
    break
  fi
  
  # Print line
  echo $last_line
  
  # Wait
  sleep $SLEEP_WAIT
done
