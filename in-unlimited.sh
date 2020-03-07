#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# sets things up to track data in `unlimited` usage windows
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
Send2Log "in-unlimited: $1" 1
if [ "$1" == "start" ] ; then
	ChangePath 'currentlyUnlimited' "1"
elif [ "$1" == "end" ] ; then
	ChangePath 'currentlyUnlimited' "0"
else
	Send2Log "in-unlimited: bad parameter -->$1" 1
fi

LogEndOfFunction
