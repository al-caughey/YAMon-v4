#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# sets up iptables entries; crontab entries, etc.
# run: /opt/YAMon4/start.sh
# History
# 2020-01-26: 4.0.7 - create tmpLastSeen if it does not exist; fixed users_created error
#					- changed name of StartCronJobs to StartScheduledJobs (to better account for cron vs cru)
#                   - add symlink for _wwwURL if it does not already exist
# 2020-01-03: 4.0.6 - added logging to WriteConfigFile; changed logic to create js directory in SetWebDirectories
# 2019-12-23: 4.0.5 - added symlink for latest-log & day-log
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

CreateUsersFile()
{
	#wget http://usage-monitoring.com/current/getDevices.php?k=29e315558d333f4ae3845f02a7edd8d0 -U "YAMon-Setup" -Oq "${tmplog}devices.txt"
	Send2Log "CreateUsersFile: Creating empty users file: $_usersFile" 2
	echo "var users_version=\"$_version\"
var users_created=\"$_ds $_ts\"
var users_updated=\"\"
//MAC -> Groups

//MAC -> IP	
	" > $_usersFile
}

SetWebDirectories()
{
	WriteConfigFile(){
		local cfgPath="${_wwwPath}js/config${_version%\.*}.js"
		Send2Log "WriteConfigFile: $cfgPath" 1
		local configVars='_installed,_updated,_router,_firmwareName,_version,_firmware,_dbkey,_updateTraffic,_ispBillingDay,_wwwData'

		>$cfgPath #empty the file
		
		IFS=$','
		for vn in $configVars ; do
			eval vv=\"\$$vn\"
			Send2Log "WriteConfigFile: $vn -> $vv" 1
			echo "var $vn = \"$vv\"" >> $cfgPath
		done
	}
	AddSoftLink(){
		Send2Log "AddSoftLink: $1 -> $2" 1
		[ -h "$2" ] && rm -fv "$2"
		ln -s "$1" "$2"
	}
	Send2Log "SetWebDirectories" 1
	[ -d "${_wwwPath}" ] || mkdir -p "${_wwwPath}"
	[ -d "${_wwwPath}js" ] || mkdir -p "${_wwwPath}js"
	chmod -R a+rX "${_wwwPath}"
	[ ! -h "/www${_wwwURL}" ] && ln -s "/tmp${_wwwURL}" "/www${_wwwURL}"

	#ln -s /tmp/www /www/yamon
	AddSoftLink "${d_baseDir}/www/css" "${_wwwPath}css"
	AddSoftLink "${d_baseDir}/www/images" "${_wwwPath}images"
	[ "$_wwwData" == 'data3/' ] && _wwwData=''
	AddSoftLink "${_path2data%/}" "${_wwwPath}${_wwwData:-data4}"
	AddSoftLink "${_path2logs%/}" "${_wwwPath}logs"
	AddSoftLink "$tmplogFile" "${_wwwPath}logs/latest-log.html"
	AddSoftLink "${_path2logs%/}/${_ds}.html" "${_wwwPath}logs/day-log.html"
	AddSoftLink "${d_baseDir}/www/yamon${_version%\.*}.html" "${_wwwPath}${_webIndex:-index.html}"
	
	WriteConfigFile
}

d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/version.sh"
source "$d_baseDir/strings/title.inc"

echo -E "$_s_title"

"${d_baseDir}/setPaths.sh"
tmplog='/tmp/yamon/'
[ -d "$tmplog" ] || mkdir -p "$tmplog"

source "${d_baseDir}/includes/shared.sh"
source "${d_baseDir}/includes/setupIPChains.sh"
source "${d_baseDir}/includes/paths.sh"
[ -f "$_lastSeenFile" ] || touch "$_lastSeenFile"
[ -f "$tmpLastSeen" ] || touch "$tmpLastSeen"

source "${d_baseDir}/includes/start-stop.sh"

echo -E "$_s_title" # echo the title again so it appears in the log file too :-)

[ -d "$_path2logs" ] || mkdir -p "$_path2logs"
[ -d "$_path2data" ] || mkdir -p "$_path2data"
[ -d "$_path2bu" ] || mkdir -p "$_path2bu"
[ -d "$_path2CurrentMonth" ] || mkdir -p "$_path2CurrentMonth"

[ ! -f "$hourlyDataFile" ] && [ -f "${_path2CurrentMonth}hourly_${_ds}.js" ] && cp "${_path2CurrentMonth}hourly_${_ds}.js" "${tmplog}"
[ ! -f "$hourlyDataFile" ] && echo -e "var hourly_created=\"${_ds} ${_ts}\"\nvar hourly_updated=\"${_ds} ${_ts}\"\n" > "$hourlyDataFile"


ln -sf $tmplog $d_baseDir
> "$macIPFile" # create and/or empty the MAC IP list files

[ ! -f "$hourlyDataFile" ] &&  [ ! -f "${_path2CurrentMonth}hourly_${_ds}.js" ] && cp "${_path2CurrentMonth}hourly_${_ds}.js" "$hourlyDataFile" 

if [ -f "$_lastSeenFile" ] ; then 
	cp "${_lastSeenFile}" "$tmpLastSeen" 
	cp "$_lastSeenFile" "${_lastSeenFile/.js/-${_ds}-${_ts}.js}"
fi

[ -z "$1" ] && rebootOrStart='Script Restarted' || rebootOrStart='Server Rebooted'
echo -e "//$rebootOrStart" >> "$hourlyDataFile"
Send2Log "YAMon:: $rebootOrStart" 2
Send2Log "YAMon:: version $_version	_loglevel: $_loglevel" 1
if [ -f "$_usersFile" ] ; then
	if [ -z "$(cat "$_usersFile" | grep "^var users_updated")" ] ;  then
		Send2Log "Start: adding users_updated to $_usersFile" 2
		ucl=$(cat "$_usersFile" | grep "^var users_created")
		sed -i "s~$ucl~$ucl\nvar users_updated=\"\"~" "$_usersFile"
	fi
else
	CreateUsersFile
fi
SetupIPChains # in /includes/setupIPChains.sh
AddNetworkInterfaces # in /includes/setupIPChains.sh

AddActiveDevices
SetWebDirectories

"${d_baseDir}/new-day.sh"
"${d_baseDir}/new-hour.sh"
"${d_baseDir}/check-network.sh"

CheckIntervalFiles

StartScheduledJobs
