#!/bin/bash

# Logs to buildkite progress of bacon build every N seconds

LOG_FILE=$1
SLEEP_WAIT=$2
last_line=""

while [ 1 ]
do
  # Retrieve last line
  line=$(tail -n 1 $LOG_FILE)

  # Exit if build is marked as complete
  if [ "$line" -eq "BUILD_COMPLETE" ]; then
    break
  fi

  # Skip if line is the same
  if [ "$line" -eq "$last_line" ]; then
    continue
  fi

  # Print line
  last_line="$line"
  echo $line

  # Wait
  sleep $SLEEP_WAIT
done
