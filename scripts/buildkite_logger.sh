#!/bin/bash

# Logs to buildkite progress of bacon build every N seconds

LOG_FILE=$1
SLEEP_WAIT=$2
last_line=""

while [ 1 ]
do
  # Retrieve last line
  line=$(tail -n 1 "$LOG_FILE")
  
  LOG_FOLDER=$(dirname "${line}")

  # Exit if build is marked as complete
  if [[ -f "$LOG_FOLDER/.finished" ]]; then
    break
  fi

  # Skip if line is the same
  if [[ "$line" == "$last_line" ]]; then
    sleep $SLEEP_WAIT
    continue
  fi

  # Get and set percentage
  percent="${line:1:3}"

  if [ -n "$percent" ]; then
    last_line="$line"
    export STAGE_PERCENT="$percent"
    echo "$line"
  fi

  # Wait
  sleep $SLEEP_WAIT
done
