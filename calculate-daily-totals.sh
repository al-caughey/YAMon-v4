#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# updates the data for the live tab
# run: manually to fill gaps or regenerate totals
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - no changes
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
# To-Do: calculate billing interval... add option for addition days or entire month as
#        in h2m.sh
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)

source "${d_baseDir}/includes/shared.sh"
source "${d_baseDir}/includes/dailytotals.sh"

[ -n "$1" ] && totalsDate="$1"
[ -z "$totalsDate" ] && totalsDate="$_ds"
_intervalDataFile="${_intervalDataFile/.js/2.js}"

Send2Log "calculate-daily-totals,sh: start --> $_intervalDataFile (totalsDate: $totalsDate)" 1

CalculateDailyTotals "$totalsDate"

LogEndOfFunction
