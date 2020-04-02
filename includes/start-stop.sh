##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# script to enable/disable entries in /etc/crontabs
# run: /opt/YAMon4/start.sh
# History
# 2020-01-26: 4.0.7 - changes to cronJobsFile, stopService & startService for Tomato
#					- renamed StartCronJobs to StartScheduledJobs
#					- fixed StopCruJobs() issue in Tomato
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - added timestamp to url in SetAccessRestrictions
# 2019-11-24: 4.0.4 - added 2>/dev/null to start/stopService calls
# 2019-06-18: development starts on initial v4 release
#
##########################################################################
 
Send2Log "start-stop" 1

if [ "$_firmware" -eq "0" ] ; then
	cronJobsFile=/tmp/cron.d/yamon_jobs
	wc=$(ps | grep -v grep | grep cron | awk '{ print $3 }')
	stopService="stopservice $wc root"
	startService="startservice $wc root"
elif [ "$_firmware" -eq "2" ] || [ "$_firmware" == "3" ] || [ "$_firmware" -eq "5" ] ; then #Tomato, AsusMerlin & variants
	Send2Log "Do nothing Firmware uses cru" 0 #Need something here or complaint of else on next line
else
	cronJobsFile=/etc/crontabs/root
	stopService="/etc/init.d/cron stop"
	startService="/etc/init.d/cron reload"
fi

ResetCron(){
	#to do --> confirm paths for other firmware variants... works in Turris & dd-wrt
	Send2Log "ResetCron: $stopService / $startService" 1
	$stopService 2>/dev/null #redirecting spurious error messages to /dev/null
	sleep 1
	$startService 2>/dev/null #redirecting spurious error messages to /dev/null
}

StartScheduledJobs(){
	SetCronJobs(){ #for firmware using cron
		touch "$cronJobsFile"
		local fileContents=$(cat "$cronJobsFile")
		local newjobs=$(echo "$fileContents" | grep -v "${d_baseDir}" | grep -v "YAMon jobs")
		local networkChecks=''
		if [ "${_check4Devices:-1}" -gt "1" ] ; then
			networkChecks="/${_check4Devices}"
		fi
		local user=''
		[ "$_firmware" -eq "0" ] && user='root'
		newjobs="${newjobs}\n#YAMon jobs: (updated $_ds)"
		newjobs="${newjobs}\n0 0 ${_ispBillingDay:-1} * * $user ${d_baseDir}/new-billing-interval.sh"
		newjobs="${newjobs}\n59 * * * * $user ${d_baseDir}/end-of-hour.sh"
		newjobs="${newjobs}\n59 23 * * * $user ${d_baseDir}/end-of-day.sh"
		newjobs="${newjobs}\n0 0 * * * $user ${d_baseDir}/new-day.sh"
		if [ "$_unlimited_usage" -eq "1" ] ; then
			local sh=$(echo "$_unlimited_start" | cut -d':' -f1)
			local sm=$(echo "$_unlimited_start" | cut -d':' -f2)
			sm=${sm#0}
			local eh=$(echo "$_unlimited_end" | cut -d':' -f1)
			local em=$(echo "$_unlimited_end" | cut -d':' -f2)
			em=${em#0}
			inUnlimited="${tmplog}inUnlimited"
			newjobs="${newjobs}\n${sm} ${sh} * * * $user ${d_baseDir}/in-unlimited.sh start"
			newjobs="${newjobs}\n${em} ${eh} * * * $user ${d_baseDir}/in-unlimited.sh end"
		fi	
		newjobs="${newjobs}\n0 * * * * $user ${d_baseDir}/new-hour.sh"
		[ "$_doLiveUpdates" -eq "1" ] && newjobs="${newjobs}\n* * * * * $user ${d_baseDir}/update-live-data.sh"
		local udt=${_updateTraffic:-4}
		newjobs="${newjobs}\n$udt-$((60 - $udt))/$udt * * * * $user ${d_baseDir}/update-reports.sh"
		# line below is seemingly not a reliable as the one above?!?
		#newjobs="${newjobs}\n*${networkChecks} * * * * $user ${d_baseDir}/check-network.sh"
		
		echo -e "$newjobs" > "$cronJobsFile"
		Send2Log "SetCronEntries: updating \`$cronJobsFile\` --> $(IndentList "$newjobs")" 1
	}

	SetCruJobs(){ #for Tomato (and other firmware using cru rather than cron)
		cru a yamon1 "0 0 ${_ispBillingDay:-1} * * ${d_baseDir}/new-billing-interval.sh"
		cru a yamon2 "59 * * * * ${d_baseDir}/end-of-hour.sh"
		cru a yamon3 "59 23 * * * ${d_baseDir}/end-of-day.sh"
		cru a yamon4 "0 0 * * * ${d_baseDir}/new-day.sh"
		if [ "$_unlimited_usage" -eq "1" ] ; then
			local sh=$(echo "$_unlimited_start" | cut -d':' -f1)
			local sm=$(echo "$_unlimited_start" | cut -d':' -f2)
			sm=${sm#0}
			local eh=$(echo "$_unlimited_end" | cut -d':' -f1)
			local em=$(echo "$_unlimited_end" | cut -d':' -f2)
			em=${em#0}
			inUnlimited="${tmplog}inUnlimited"
			cru a yamon5 "${sm} ${sh} * * * ${d_baseDir}/in-unlimited.sh start"
			cru a yamon6 "${em} ${eh} * * * ${d_baseDir}/in-unlimited.sh end"
		fi	
		cru a yamon7 "0 * * * * ${d_baseDir}/new-hour.sh"
		[ "$_doLiveUpdates" -eq "1" ] && cru a yamon8 "* * * * * ${d_baseDir}/update-live-data.sh"
		local udt=${_updateTraffic:-4}
		cru a yamon9 "$udt-$((60 - $udt))/$udt * * * * ${d_baseDir}/update-reports.sh"
		Send2Log "Setting cru jobs for: $(IndentList "$(cru l | grep 'yamon')")"
	}

	Send2Log "StartScheduledJobs - started..." 0
	if [ "$_firmware" -eq "3" ] || [ "$_firmware" -eq "2" ] || [ "$_firmware" -eq "5" ]; then
		local scheduler='cru'
		SetCruJobs
	else
		local scheduler='cron'
		SetCronJobs
		ResetCron
	fi
	Send2Log "The YAMon jobs have been scheduled in \`$scheduler\`... run ${d_baseDir}/pause.sh to pause or stop the scripts" 99
}
StopScheduledJobs(){
	StopCronJobs(){
		nfc=""
		local jobList=$(cat "$cronJobsFile")
		IFS=$'\n'
		for job in $jobList
		do
			[ ! -z $(echo "$line" | grep "$d_baseDir" | grep -v '^##') ] && line="## $job"
			[ -z $nfc ] && nfc="$job" && continue
			nfc="$nfc\n$job"
		done
		unset $IFS
		echo -e "$nfc" > $cronJobsFile

		Send2Log "StopCronJobs: $(IndentList "$nfc")" 1
		ResetCron
	}

	StopCruJobs(){
		local jobList=$(cru l | grep 'yamon' | tr -d '#') # Remove '#' from cru id #yamon*#
		IFS=$'\n'
		for job in $jobList
		do
			local jn=$(echo "$job" | awk '{ print $7 }')
			cru d "$jn"
		done
		unset $IFS
		Send2Log "StopCruJobs: $(IndentList "$(cru l | grep 'yamon')")" 1
	}
	
	if [ "$_firmware" -eq "3" ] || [ "$_firmware" -eq "2" ] || [ "$_firmware" -eq "5" ]; then
		local scheduler='cru'
		StopCruJobs
	else
		local scheduler='cron'
		StopCronJobs
	fi
	Send2Log "The YAMon jobs in \`$scheduler\` have been paused... run ${d_baseDir}/start.sh to restart the scripts" 99
}
SetAccessRestrictions(){
	local fileContents=$(cat "$cronJobsFile")
	local otherjobs=$(echo "$fileContents" | grep -v "#Access Restriction" | grep -v "block.sh")
	
	local user=''
	local security_protocol=''
	local protocol='http://'
	local fts=$(date +"%s")
	local url="www.usage-monitoring.com/current/GetAccessRules.php?db=$_dbkey&$fts"
	
	if [ "$_firmware" -eq "0" ] ; then
		user='root'
		security_protocol='--secure-protocol=auto'
		protocol='http://'
	fi
	dst="$tmplog/ac-rules.txt"
	prototol='http://'
	security_protocol=''
	wget "$prototol$url" $security_protocol -qO "$dst"
	local ac_jobs=$(cat $dst | sed -e "s~<user>~$user~" -e "s~<path>~$d_baseDir/~")
	if [ -n "$(echo "$ac_jobs" | grep "^Error")" ] ; then
		Send2Log "SetAccessRestrictions: Error in download --> $(IndentList "$ac_jobs")" 1
	else
		echo -e "$otherjobs\n$ac_jobs" > "$cronJobsFile"
		Send2Log "SetAccessRestrictions: adding access rules to \`$cronJobsFile\` --> $(IndentList "$ac_jobs")" 1
	fi
	
	IFS=$'\n'
	local cm=$(date +"%m")
	local cd=$(date +"%u")

	for job in $ac_jobs ; do
		local jtime=$(echo "$job" | awk '{ print $2":"$1 }')
		local jday=$(echo "$job" | awk '{print $5}')
		local jmonth=$(echo "$job" | awk '{print $4}')
		Send2Log "SetAccessRestrictions: jtime=$jtime / _ts=$_ts ($jday - $jmonth)" 0
		if [ "$jmonth" == '*' ] || [ -n "$(echo "$jmonth" | grep -e "\b$cm\b")" ] ; then
			if [ "$jday" == '*' ] || [ -n "$(echo "$jday" | grep -e "\b$cd\b")" ] ; then
				if [ "$_ts" \> "$jtime" ] ; then
					local actualJob="${d_baseDir}/block.sh$(echo "$job" | awk '{$1=$2=$3=$4=$5=$6=""; print $0 }' | tr -s ' ')"
					Send2Log "SetAccessRestrictions: need to run ${actualJob## }" 1
					eval "${d_baseDir}/block.sh$(echo "$job" | awk '{$1=$2=$3=$4=$5=$6=""; print $0 }' | tr -s ' ')"
				fi
			fi
		fi
	done
}
