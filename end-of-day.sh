#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# wraps things up at the end of each day
# run: by cron
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - no changes
# 2019-11-24: 4.0.4 - added '2>/dev/null ' to tar call to prevent spurious messages in the logs
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

DeactiveIdleDevices(){
	local _activeIPs=$(cat "$_usersFile" | grep -e "^mac2ip({.*})$" | grep '"active":"1"')
	local lastseen=''
	[ -f "$_lastSeenFile" ] && lastseen=$(cat "$_lastSeenFile" | grep -e "^lastseen({.*})$")
	IFS=$'\n'
	Send2Log "DeactiveIdleDevices - _activeIPs"
	for line in $_activeIPs 
	do	
		[ -z "$line" ] && continue
		local id=$(GetField "$line" 'id')
		local ls=$(GetField "$(echo "$lastseen" | grep "$id")" 'last-seen')
		#ToDo - add a check for last-seen more than 30 days old
		if [ -z "$ls" ] ; then
			newline=$(echo "${line/\"active\":\"1\"/\"active\":\"0\"}")
			sed -i "s~$line~$newline~" "$_usersFile"
			#To Do... cull the inactive entries from iptables?!?
			Send2Log "DeactiveIdleDevices: $id set to inactive (based upon users.js)" 1
			local changes1=1
		fi
	done
	[ -z "$changes1" ] && Send2Log "DeactiveIdleDevices: no active devices deactivated" 

	local _inActiveIPs=$(cat "$_usersFile" | grep -e "^mac2ip({.*})$" | grep '"active":"0"')

	Send2Log "DeactiveIdleDevices - lastseen"
	for line in $lastseen 
	do
		[ -z "$line" ] && continue
		local id=$(GetField "$line" 'id')
		local wl=$(echo "$_inActiveIPs" | grep "$id")
		if [ -n "$wl" ] ; then
			newline=$(echo "${wl/\"active\":\"0\"/\"active\":\"1\"}")
			sed -i "s~$wl~$newline~" "$_usersFile"
			Send2Log "DeactiveIdleDevices: $id set to active (based upon lastseen.js)" 1
			local changes2=1
		fi
	done
	[ -z "$changes2" ] && Send2Log "DeactiveIdleDevices: no deactived devices activated"
	[ -n "$changes1" ] || [ -n "$changes2" ] && UsersJSUpdated
}

d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/shared.sh"
source "${d_baseDir}/includes/dailytotals.sh"
[ -n "$1" ] && _ds="$1"
sleep 75 # wait until all tasks for the day should've been completed... may have to adjust this value

Send2Log "End of day: $_ds" 1
Send2Log "End of day: copy $hourlyDataFile --> $_path2CurrentMonth"
cp "$hourlyDataFile" "$_path2CurrentMonth"

#Calculate the daily totals
Send2Log "End of day: tally the traffic for the day and update the monthly file"
CalculateDailyTotals ## no param --> implies value of _ds

Send2Log "End of day: backup files as required" 
cp "$tmplogFile" "$_path2logs"

[ "$_doDailyBU" -eq "1" ] && tar -cf "${_path2bu}bu-${_ds}.tar.gz" $_usersFile $tmpLastSeen $(find -L ${d_baseDir} | grep "$_ds") 2>/dev/null && Send2Log "End of day: archive date specific files to '${_path2bu}bu-${_ds}.tar.gz'"

rm $(find "$tmplog" | grep "$_ds") #delete the date specific files

DeactiveIdleDevices

LogEndOfFunction
