#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# script to create the date path/files for a new billing interval; and
#    optionally purge log and backup files more than 30 days old (see purge.sh)
# run: by cron
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - no changes
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/shared.sh"

[ -z "$1" ] && newBillingDate="$_ds" || newBillingDate="$1"
yr=$(echo $newBillingDate | cut -d'-' -f1)
mo=$(echo $newBillingDate | cut -d'-' -f2)
da=$(echo $newBillingDate | cut -d'-' -f3)

[ "${da#0}" == "$_ispBillingDay" ] || echo "New Billing Interval: current date (${da#0}) does not match _ispBillingDay ($_ispBillingDay)... exitting!" 2 || exit 0

_currentInterval="${yr}-${mo}"
Send2Log "New Billing Interval: $_currentInterval" 2
_path2CurrentMonth="${_path2data}${_currentInterval/-//}/"
_intervalDataFile="$_path2CurrentMonth${_currentInterval}-mac_usage.js"

ChangePath '_currentInterval' "$_currentInterval"
ChangePath '_path2CurrentMonth' "$_path2CurrentMonth"
ChangePath '_intervalDataFile' "$_intervalDataFile"

CheckIntervalFiles

# purge old files
[ "$_purgeOldFiles" -eq "1" ] && "${d_baseDir}/purge.sh"

LogEndOfFunction
