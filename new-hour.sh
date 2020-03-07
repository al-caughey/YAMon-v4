#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# runs tasks needed to start a new hour
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

hr=$(echo $_ts | cut -d':' -f1)
Send2Log "new hour: Start of hour $hr" 1

rawtraffic_hr="${tmplog}raw-traffic-$_ds-$hr.txt"
ChangePath 'rawtraffic_hr' "$rawtraffic_hr"

[ ! -f "$rawtraffic_hr" ] && > "$rawtraffic_hr"
Send2Log "new hour: created new temporary hour file: $rawtraffic_hr"

sleep 5
[ -z "$(grep "// Hour: $hr" "$hourlyDataFile")" ] && echo -e "\n// Hour: $hr" >> "$hourlyDataFile"

LogEndOfFunction
