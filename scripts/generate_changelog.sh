#!/bin/bash

# Create simplified changelog from rom created changelog since date - v1.0

if [ $# -lt 2 ]; then
  echo "USAGE: $0 [CHANGELOG FILE] [DATE]"
  exit 1
fi

if [ ! -f $1 ]; then
  echo "$0 - Error: '$1' doesn't exist."
  exit 1
fi

changelog_file="$1"
specified_date="$2"

# Removed padding around changes and shows individual commits
changelog_trimmed=$(sed "/$specified_date/q" $changelog_file | grep "* " -A 1 | grep -v "*" | sed '/^--/d' | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}' | sort -u)

# Remove some commits based on main title
changelog_trimmed=$(echo "$changelog_trimmed" | sed '/repopick/d')

# Echo to stdout
echo "$changelog_trimmed"
