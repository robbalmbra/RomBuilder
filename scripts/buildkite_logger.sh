#!/bin/bash

# Logs to buildkite progress of bacon build every N seconds

LOG_FILE=$1
SLEEP_WAIT=$2

while [ 1 ]
do
  last_line=$(tail -n 1 $LOG_FILE)
  echo $last_line
  sleep $SLEEP_WAIT
done
