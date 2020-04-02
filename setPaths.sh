#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# generate /includes/paths.sh with computed paths files & logs; also computed function names(shared between one or more scripts)
# values generated during setup & verified on startup or on demand
# run: /opt/YAMon4/setPaths.sh
# History
# 2020-01-26: 4.0.7 - removed routerfile entry from paths (as no longer used); added defensive default when checking if IPv6 is enabled
#                   - added another check for ipv6Enabled & static leases for Tomato (thx tvlz); combined AsusMerlin & Tomato entries
# 2020-01-26: 4.0.6 - added {xxx:-_} defaults in a number of spots
# 2019-12-23: 4.0.5 - no changes
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)

check4Overflow(){
	local n=1
	local a=9
	local b=9
	local ob=0
	while [ true ] ; do 
		c=$(($a + $b))
		[ $c -lt $a ] || [ $c -lt $b ] && break #check for sum overflow
		ob=$b
		a=$(($a * 10 + 1))
		b=$(($b * 10 + 9))
		[ $b -lt $ob ] && break #check for value overflow
		[ $n -eq 32 ] && break #check for max digits 
		n=$(($n + 1))
	done
	echo $n
}

if [ -n "$1" ] && [ "$1" == 'clean' ] ; then
	echo 'Clean install...'

	[ -d "/tmp/yamon/" ] && rmdir /tmp/yamon/
	
	[ -d "$d_baseDir/daily-bu/" ] && rm -r "$d_baseDir/daily-bu/" && rmdir $d_baseDir/daily-bu/
	[ -d "$d_baseDir/data/" ] && rm -r "$d_baseDir/data/" && rmdir $d_baseDir/data/
	[ -d "$d_baseDir/logs/" ] && rm -r "$d_baseDir/logs/" && rmdir $d_baseDir/logs/
	
	[ -f "$d_baseDir/includes/paths.sh" ] && rm $d_baseDir/includes/paths.sh
fi

pathsFile="${d_baseDir}/includes/paths.sh"
[ ! -f "$pathsFile" ] && touch "$pathsFile"

source "${d_baseDir}/includes/shared.sh"

echo "# generated $_ds $_ts" > "${pathsFile}"

echo -e "\n#Generic functions" >> "${pathsFile}"
	tmplog='/tmp/yamon/'
	[ -d "$tmplog" ] || mkdir -p "$tmplog"
	
	if [ "${_logDir:0:1}" == "/" ] ; then
		AddEntry '_path2logs' "${_logDir}" #absolute path to the logs
	else
		AddEntry '_path2logs' "${d_baseDir}/${_logDir:-logs/}"
	fi
	if [ "${_dataDir:0:1}" == "/" ] ; then
		_path2data="${_dataDir}" #absolute path to the logs
	else
		_path2data="${d_baseDir}/${_dataDir:-data/}"
	fi
	AddEntry '_path2data' "${_path2data}"
	AddEntry 'dailyLogFile' "${_path2logs}${_ds}.html"
	yr=$(echo $_ds | cut -d'-' -f1)
	mo=$(echo $_ds | cut -d'-' -f2)
	da=$(echo $_ds | cut -d'-' -f3)
	hr=$(echo $_ts | cut -d':' -f1)
	mo=${mo#0}
	[ ${da#0} -lt ${_ispBillingDay:-1} ] && mo=$(($mo - 1))
	
	if [ "$mo" -eq "0" ]; then
		mo='12'
		yr=$(($yr - 1))
	else
		mo=$(printf %02d $mo)
	fi
	_currentInterval="${yr}-${mo}"
	AddEntry '_currentInterval' "$_currentInterval"
	
	_path2CurrentMonth="${_path2data}${_currentInterval/-//}/"
	AddEntry '_path2CurrentMonth' "$_path2CurrentMonth"
	AddEntry '_intervalDataFile' "$_path2CurrentMonth${_currentInterval}-mac_usage.js"

	AddEntry '_uptime' "$(cat /proc/uptime | cut -d' ' -f1)"
	AddEntry 'lastCheckinHour' "$(( 60 -  ${_updateTraffic:-4}))"

	if [ "${_doDailyBU:-1}" -eq "1" ] ; then
		if [ "${_dailyBUPath:0:1}" == "/" ] ; then
			AddEntry '_path2bu' "${_dailyBUPath}" #absolute path to the daily backups (if _doDailyBU=1
		else
			AddEntry '_path2bu' "${d_baseDir}/${_dailyBUPath:-daily-bu/}"
		fi
	fi
	AddEntry '_usersFile' "${_path2data}users.js"
	AddEntry 'tmpUsersFile' "${tmplog}users.js"
	
	AddEntry '_lastSeenFile' "${_path2data}lastseen.js"
	AddEntry 'tmpLastSeen' "${tmplog}lastseen.js"

	AddEntry 'rawtraffic_day' "${_path2CurrentMonth}raw-traffic-$_ds.txt"
	AddEntry 'rawtraffic_hr' "${tmplog}raw-traffic-$_ds-$hr.txt"

	AddEntry 'hourlyDataFile' "${tmplog}hourly_${_ds}.js"
	AddEntry 'macIPFile' "${tmplog}mac-ip.txt"

	echo -e "\n#ip v4 & v6 paths & functions" >> "${pathsFile}"
	AddEntry 'YAMON_IPTABLES' 'YAMONv40' #now the same rule names/prefix in both iptables & ip6tables
	AddEntry '_generic_ipv4' '0.0.0.0/0'
	AddEntry '_generic_ipv6' '::/0'
	_path2ip=$(which ip)

	$($_path2ip neigh show > "${tmplog}ipv6.txt" 2>&1)
	[ $? -eq 1 ] && _IPCmd='' || _IPCmd='ip neigh show'
	AddEntry '_IPCmd' "$_IPCmd"
	rm "${tmplog}ipv6.txt"

	AddEntry 'send2FTP' "Send2FTP_"${_enable_ftp}

	echo -e "\n#livedata.sh" >> "${pathsFile}"
#paths
	if [ -f "/proc/net/nf_conntrack" ] ; then
		AddEntry '_conntrack' '/proc/net/nf_conntrack'
		AddEntry '_conntrack_awk' 'BEGIN { printf "var curr_connections=["} { gsub(/(src|dst|sport|dport|bytes)=/, ""); if($3 == "tcp"){ printf "[\"%s\",\"%s\",%s,\"%s\",%s,%s],",$3,$7,$9,$8,$10,$12;} else if($3 == "udp"){ printf "[\"%s\",\"%s\",%s,\"%s\",%s,%s],",$3,$6,$8,$7,$9,$11;} else { printf "[\"%s\",\"%s\",,\"%s\",,%s],",$3,$6,$7,$9;} }'
	else
		AddEntry '_conntrack' '/proc/net/ip_conntrack'
		AddEntry '_conntrack_awk' 'BEGIN { printf "var curr_connections=["} { gsub(/(src|dst|sport|dport|bytes)=/, ""); if($1 == "tcp"){ printf "[\"%s\",\"%s\",%s,\"%s\",%s,%s],",$1,$5,$7,$6,$8,$10;} else if($3 == "udp"){ printf "[\"%s\",\"%s\",%s,\"%s\",%s,%s],",$1,$4,$6,$5,$7,$9;} else { printf "[\"%s\",\"%s\",,\"%s\",,%s],",$1,$4,$5,$9;} }'
	fi
	
	if [ "${_doLiveUpdates:-1}" -eq "1" ] ; then
		AddEntry '_liveFilePath' "${_wwwPath}${_wwwJS:-js/}live_data4.js"
		AddEntry 'doCurrConnections' "CurrentConnections_${_doCurrConnections}"
		AddEntry 'doArchiveLiveUpdates' "ArchiveLiveUpdates_${_doArchiveLiveUpdates}"
		[ "${_doArchiveLiveUpdates:-0}" -eq "1" ] && AddEntry '_liveArchiveFilePath' "$_path2CurrentMonth${ds}-live_data4.js"
	fi
#computed function names

	if [ "${_unlimited_usage:-0}" -eq "1" ] ; then
		AddEntry 'hourlyDataTemplate' 'hourlyData4({\"id\":\"%s\",\"hour\":\"%s\",\"down\":\"%s\",\"up\":\"%s\",\"ul_do\":\"%s\",\"ul_up\":\"%s\"})'

	else
		AddEntry 'hourlyDataTemplate' 'hourlyData4({\"id\":\"%s\",\"hour\":\"%s\",\"down\":\"%s\",\"up\":\"%s\"})'
	fi
	AddEntry 'currentlyUnlimited' "0"
	
#Firmware specfic & dependent entries

echo -e "\n#Firmware specfic & dependent entries:" >> "${pathsFile}"

	if [ "$_firmware" -eq "0" ] ; then #DD-WRT
		AddEntry 'nameFromStaticLeases' "StaticLeases_DDWRT"
		AddEntry 'deviceIPField' '3'
		AddEntry 'deviceNameField' '2'
		AddEntry '_dnsmasq_conf' "/tmp/dnsmasq.conf"
		AddEntry '_dnsmasq_leases' "/tmp/dnsmasq.leases"
		AddEntry "_wwwPath" "${_wwwPath:-/tmp/www/}"
		AddEntry "_wwwURL" '/user'
		_lan_iface='br-0'
		AddEntry "_iptablesWait" ""
		
		hip6=$(nvram get ipv6_enable)
		[ "${hip6:-0}" -eq '1' ] && ipv6Enabled=1

	elif [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] || [ "$_firmware" -eq "6" ] || [ "$_firmware" -eq "7" ] ; then #OpenWRT & variants
		AddEntry 'nameFromStaticLeases' "StaticLeases_OpenWRT"
		AddEntry 'deviceIPField' '2'
		AddEntry 'deviceNameField' '3'
		AddEntry '_dnsmasq_conf' "/tmp/etc/dnsmasq.conf"
		AddEntry '_dnsmasq_leases' "/tmp/dhcp.leases"
		AddEntry "_wwwPath" "${_wwwPath:-/tmp/www/}"
		AddEntry "_wwwURL" '/yamon'
		_lan_iface='br-lan'
		AddEntry "_iptablesWait" '-w -W1'
		
		hip6=$( uci show ddns.myddns_ipv6.use_ipv6 | cut -d'=' -f2 | sed -e "s~'~~g")
		[ "${hip6:-0}" -eq '1' ] && ipv6Enabled=1
	
	elif [ "$_firmware" -eq "2" ] || [ "$_firmware" -eq "3" ] || [ "$_firmware" -eq "5" ] ; then #AsusMerlin, Tomato & variants
		AddEntry 'nameFromStaticLeases' "StaticLeases_Merlin_Tomato"
		AddEntry 'deviceIPField' '2'
		AddEntry 'deviceNameField' '3'
		AddEntry '_dnsmasq_conf' "/tmp/etc/dnsmasq.conf"
		AddEntry '_dnsmasq_leases' "/tmp/var/lib/misc/dnsmasq.leases"
		AddEntry "_wwwPath" "${_wwwPath:-/tmp/var/wwwext/}"
		AddEntry "_wwwURL" '/user'
		_lan_iface='br0'
		AddEntry "_iptablesWait" '-w -W1'
		
		hse6=$(nvram get ipv6_service):-disabled
		[ "${hse6:-disabled}" != 'disabled' ] && ipv6Enabled=1

	else #otherwise... should never get to this
		AddEntry 'nameFromStaticLeases' "NullFunction"
		AddEntry '_dnsmasq_conf' "/tmp/etc/dnsmasq.conf"
		AddEntry '_dnsmasq_leases' "/tmp/dhcp.leases"
		AddEntry 'deviceIPField' '3'
		AddEntry 'deviceNameField' '2'
		AddEntry "_wwwPath" "${_wwwPath:-/tmp/www/}"
		AddEntry "_wwwURL" '/user'
		_lan_iface='br-0'
		AddEntry "_iptablesWait" ""
	fi
	AddEntry "_lan_iface" "$_lan_iface"
	AddEntry "_interfaces" "$_lan_iface"
	
	if [ -z "$ipv6Enabled" ] ; then 
		AddEntry 'ip6tablesFn' 'NoIP6'
		AddEntry 'ip6Enabled' ''
	else
		AddEntry 'ip6tablesFn' 'IP6Enabled'
		AddEntry 'ip6Enabled' '1'
	fi
	
	if [ -f "$_dnsmasq_conf" ] ; then
		AddEntry 'nameFromDNSMasqConf' "DNSMasqConf"
	else
		AddEntry 'nameFromDNSMasqConf' "NullFunction"
	fi
	if [ -f "$_dnsmasq_leases" ] ; then 
		AddEntry 'nameFromDNSMasqLease' "DNSMasqLease"
	else
		AddEntry 'nameFromDNSMasqLease' "NullFunction"
	fi
	AddEntry '_max_digits' "$(check4Overflow)"
	
	
# Set nice level of current PID to 10 (low priority)
if [ -n "$(which renice)" ] ; then 
	AddEntry '_setRenice' 'SetRenice'
else
	AddEntry '_setRenice' 'NoRenice'
fi
