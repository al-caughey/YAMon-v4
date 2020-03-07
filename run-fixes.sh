#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# compares files on the router with those at https://usage-monitoring.com
# run: manually and by install
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - added... runs includes/fixes.sh 
#                     (corrects interfaces totals in monthly data file)
##########################################################################

showEcho=1
d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/shared.sh"

echo -e "Running fixes.sh... this will likely take several minutes.

Thank you for your patience.
"
source "${d_baseDir}/includes/fixes.sh"