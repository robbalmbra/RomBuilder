#!/bin/bash

if [ $# -lt 2 ]; then
  echo "USAGE: $0 [DAYS] [OUTPUT_FILE]"
  exit 1
fi

day_count=$1
output_file=$2
repo forall -pc git log --reverse --no-merges --since=$day_count.days.ago | grep "Date:" -A 2 | grep -v "Date:" | sed '/^--/d' | sed '/^$/d' | sed 's/^ *//g' | sort -u >> $output_file
