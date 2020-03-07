#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# pauses the current YAMon jobs in /etc/crontabs/root 
# run: /opt/YAMon4/pause.sh
# History
# 2020-01-26: 4.0.7 - changed name of StopCronJobs to StopScheduledJobs (to better account for firmware that uses cru rather than cron
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - no changes 
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/shared.sh"
Send2Log "Running pause.sh" 2
source "${d_baseDir}/includes/start-stop.sh"

StopScheduledJobs
