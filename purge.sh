#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# Purges old files from logs and daily-bu folders
# Run - manually on demand or one per billing interval
# parameters: optional #_of_days
# e.g., `/opt/YAMon3/purge.sh 14` to delete all logs & backups create more 
# that 2 weeks ago. If null; defaults to 30 days
#
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - no changes
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18): first version
#
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/shared.sh"
Send2Log "Running purge.sh" 2
days=${1:-30}

PurgeFromFolder(){
	local purgePath="$1"
	local extension="${2:-html}"
	local fl=$(find "${purgePath}" -name "*.$extension" -mtime +$days)
	if [ -z "$fl" ] ; then
		Send2Log "Purge: nothing to delete in `$purgePath` (days: $days)" 1 
		return
	fi
	
	Send2Log "Purge: deleted `*.$extension` from `$purgePath` (days: $days) $(IndentList "$fl")" 2

	IFS=$'\n'
	for ofp in $fl 
	do
		Send2Log "Purge: deleted `$ofp`" 1
		rm -f "$ofp"
	done
	unset IFS
}

PurgeFromFolder "${_path2logs}"
[ "$_doDailyBU" -eq "1" ] && PurgeFromFolder "${_path2bu}" 'gz'
