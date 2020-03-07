#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# tidies up things just after the end of each hour
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
showEcho=1
source "${d_baseDir}/includes/shared.sh"
source "${d_baseDir}/includes/start-stop.sh"

Send2Log "getACRules: " 2

"${d_baseDir}/check-network.sh"

[ -n "$_dbkey" ] && SetAccessRestrictions

ResetCron

LogEndOfFunction
