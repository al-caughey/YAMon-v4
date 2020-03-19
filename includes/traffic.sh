##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# functions to tally traffic from iptables
#
# Run - by cron jobs (update-reports & end-of-hour)
#
# History
# 2020-01-26: 4.0.7 - moved GetMACbyIP to shared.sh; allowed RETURN in iptables results 
#                   - check for missing entries in mac-ip file; fixed LOG vs RETURN for final entry in YAMONv40
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - minor tweak to loglevel of traffic at the end of the hour; 
#                     removed brace brackets around memory in Totals
#					  changed lastCheckinHour to gt rather than ge (and fixed a big issue with this)
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
# To Do:
#	* allow comma separated list of guest interfaces
#	* add ip6 addresses for interfaces
#
##########################################################################

hr=$(echo "$_ts" | cut -d':' -f1)
mm=$(echo "$_ts" | cut -d':' -f2)

sm=$(printf %02d $(( ${mm#0} - ${_updateTraffic:-4} )))
Send2Log "traffic.sh: --> $hr:$sm -> $hr:$mm" 1

GetMemory(){
	GetMemoryField()
	{
		local result=$(echo "$meminfo" | grep "^$1:" | awk '{print $2}')
		echo "${result:-0}"
		Send2Log "GetMemoryField: $1=$result"
	}
	local meminfo=$(cat /proc/meminfo)
	local freeMem=$(GetMemoryField "MemFree")
	local availMem=$(( $freeMem + $(GetMemoryField "Buffers") + $(GetMemoryField "Cached") ))
	local totMem=$(GetMemoryField "MemTotal")
	Send2Log "GetMemoryField: memory --> $freeMem,$availMem,$totMem"
	echo "$freeMem,$availMem,$totMem"
}

GetInterfaceTraffic(){
	#pnd=$(cat "/proc/net/dev" | egrep "${_interfaces//,/|}")
	pnd=$(cat "/proc/net/dev" | grep -E "${_interfaces//,/|}")
	local iTotals=""

	IFS=$'\n'
	for line in $pnd
	do
		local interface=$(echo "$line" | awk '{ print $1 }')
		local interfaceVar="interface_$(echo "$line" | awk '{ print $1 }' | sed -e 's~\.~_~' -e 's~-~_~' -e 's~:~~')"
		local current_down=$(echo "$line" | awk '{ print $10 }')
		local current_up=$(echo "$line" | awk '{ print $2 }')
		eval ov=\"\$$interfaceVar\"
		local new_down=$(( $current_down - $(echo "$ov" | cut -d',' -f1) ))
		local new_up=$(( $current_up - $(echo "$ov" | cut -d',' -f2) ))
		local interfaceLine="{\"n\":\"${interface%:}\", \"t\":\"$new_down,$new_up\"}"
		Send2Log "GetInterfaceTraffic: interfaceLine=$interfaceLine --> $line ($ov)" 1
		iTotals="$iTotals, $interfaceLine"
		if [ "$mm" -gt "$lastCheckinHour" ] ; then
			ChangePath "$interfaceVar" "$current_down,$current_up"
		fi
	done
	Send2Log "GetInterfaceTraffic - traffic by interface --> ${iTotals#,}"
	echo "${iTotals#,}"
}

GetTraffic(){

	IP6Enabled(){
		echo "$(ip6tables -L "$YAMON_IPTABLES" "$vnx" | awk '{ print $2,$7,$8 }' | grep "^[1-9]")"
	}
	NoIP6(){
		echo ''
	}

	local vnx=${1:--vnx}
	local ltrl=0
	[ "$vnx" == '-vnxZ' ] && ltrl=1
	Send2Log "GetTraffic - $vnx ($ltrl)" 0
	
	local macIPList=$(cat "$macIPFile")
	
	local ip4t=$(iptables -L "$YAMON_IPTABLES" "$vnx" | awk '{ print $2,$8,$9 }' | grep "^[1-9]")
	local ip6t="$ip6tablesFn"
	
	[ -z "$ip4t" ] && Send2Log "GetTraffic - No IPv4 traffic"
	[ -z "$ip6t" ] && Send2Log "GetTraffic - No IPv6 traffic"
	if [ -z "$ip4t" ] && [ -z "$ip4t" ] ; then
		Send2Log "GetTraffic - No traffic at all... checking chains!" 3
		> $macIPFile
		source "${d_baseDir}/includes/setupIPChains.sh"
		SetupIPChains
		return
	fi
	local ipt="$ip4t\n$ip6"
	
	tls=$(date +"%H:%M:%S")
	local intervalTraffic=''
	local total_down=0
	local total_up=0
	while [ 1 ] ;
	do
		[ -z "$ipt" ] && break
		
		fl=$(echo -e "$ipt" | head -n 1)
		[ -z "$fl" ] && break
		local ip=$(echo "$fl" | cut -d' ' -f2)
		
		if [ "$_generic_ipv4" == "$ip" ] || [ "$_generic_ipv6" == "$ip" ] ; then
			ip=$(echo "$fl" | cut -d' ' -f3)
		fi
		local tip="\b${ip//\./\\.}\b"
		
		Send2Log "GetTraffic: $fl / $ip)" 0
		
		if [ "$_generic_ipv4" == "$ip" ] || [ "$_generic_ipv6" == "$ip" ] ; then
			#unmatched traffic
			Send2Log "GetTraffic: Unmatched traffic $(IndentList "$fl")" 2
			# (so check-network is only executed when there is new unmatched data)
			${d_baseDir}/check-network.sh
			UpdateLastSeen "${_generic_mac}-${ip}" "$tls"
			local do=$(echo "$ipt" | cut -d' ' -f1)
			Send2Log "GetTraffic: down: $do / $total_down " 1
			total_down=$(( $total_down + ${do:-0} )) #assuming total_up is zero because all traffic goes to a single iptable rule
			local newLine="hourlyData4({ \"id\":\"$_generic_mac-$ip\", \"hour\":\"$hr\", \"traffic\":\"${do:-0},0,$(( ${do:-0} * $currentlyUnlimited )),0\" })"
			intervalTraffic="$intervalTraffic\n$newLine"
			
			#delete the final RETURN/LOG entry in YAMONv40 to reset the totals to zero 
			local wl=$(iptables -L "$YAMON_IPTABLES" -n --line-numbers | grep LOG | awk '{ print $1 }')
			[ -n "$wl" ] && iptables -D "$YAMON_IPTABLES" "$wl"
			wr=$(iptables -L "$YAMON_IPTABLES" -n --line-numbers | grep RETURN | awk '{ print $1 }')
			[ -n "$wr" ] && iptables -D "$YAMON_IPTABLES" "$wr"
			
			if [ "$_logNoMatchingMac" -eq "1" ] ; then
				iptables -A "$YAMON_IPTABLES" -j LOG --log-prefix "YAMon: "
				Send2Log "GetTraffic: re-zeroed LOG rule in $YAMON_IPTABLES (entry #$wo)" 2
			else
				iptables -A "$YAMON_IPTABLES" -j RETURN
				Send2Log "GetTraffic: re-zeroed RETURN rule in $YAMON_IPTABLES (entry #$wo)" 2
			fi
			
			ipt=$(echo -e "$ipt" | grep -v "$fl") #delete just the first entry from the list of IPs
		else
			local mac=$(echo "$macIPList" | grep "$tip" | cut -d' ' -f1)
			if [ -z "$mac" ] ; then
				mac=$(GetMACbyIP "$ip")
				Send2Log "GetTraffic: no matching entry for $fl.  Appending \`$mac $ip\` to macIPFile" 2
				echo -e "$mac $ip" >> "$macIPFile"
				Send2Log "GetTraffic: Checking users.js for \`$mac $ip\`" 1
				CheckMAC2IPinUserJS "$mac" "$ip"
				CheckIPTableEntry "$i"
				CheckMAC2GroupinUserJS "$mac" ""
			fi

			if [ -n "$mac" ] ; then
				local do=$(echo "$ipt" | grep -E "($_generic_ipv4|$_generic_ipv6) $tip\b" | cut -d' ' -f1)
				local up=$(echo "$ipt" | grep -E "$tip ($_generic_ipv4|$_generic_ipv6)" | cut -d' ' -f1)
				total_down=$(( $total_down + ${do:-0} ))
				total_up=$(( $total_up + ${up:-0} ))
				Send2Log "GetTraffic: $mac-$ip / ${do:-0} / ${up:-0} / $hr"
				local newLine="hourlyData4({ \"id\":\"$mac-$ip\", \"hour\":\"$hr\", \"traffic\":\"${do:-0},${up:-0},$(( ${do:-0} * $currentlyUnlimited )),$(( ${up:-0} * $currentlyUnlimited ))\" })"
				intervalTraffic="$intervalTraffic\n$newLine"
				UpdateLastSeen "$mac-$ip" "$tls"
			else
				Send2Log "GetTraffic: still no matching mac for '$ip'?!? skipping this entry$(IndentList "$fl")" 3
			fi
			ipt=$(echo -e "$ipt" | grep -v "$tip") #delete all matching entries for the current IP
		fi
	done
	intervalTraffic=$(echo -e "$intervalTraffic" | grep -e "^hourlyData4({ .* })$")
	
	local hrlyData=$(cat "$hourlyDataFile")
	
	local currentUptime=$(cat /proc/uptime | cut -d' ' -f1)
	[ -z "$currentUptime" ] && Send2Log "GetTraffic: currentUptime is null?!?" 2

	if [ -n "$currentUptime" ] && [ "$currentUptime" \< "$_uptime" ] ; then
		local rebootFile="${tmplog}reboot-${_ds}.js"
		Send2Log "GetTraffic: rebooted ($currentUptime < $_uptime) --> save current hour data to reboot.js" 2
		echo "//Uptime: $currentUptime < $_uptime" >> "$rebootFile"
		echo "$hrlyData" | grep "\"hour\":\"$hr\"" >> "$rebootFile"
		cp "$rebootFile" "$_path2CurrentMonth"
	fi
	
	local interfaceTotals=$(GetInterfaceTraffic)
	local memoryTotals=$(GetMemory)
	local disk_utilization=$(df "${d_baseDir}" | tail -n 1 | awk '{print $5}')

	totalsLine="Totals({ \"hour\":\"$hr\", \"uptime\":\"$currentUptime\", \"interval\":\"$total_down,$total_up\",\"interfaces\":'[$interfaceTotals]',\"memory\":'$memoryTotals',\"disk_utilization\":'$disk_utilization' })"

	if [ -n  "$intervalTraffic" ] ; then
		Send2Log "GetTraffic ($hr:$mm --> $vnx): intervalTraffic --> $(IndentList "$intervalTraffic\n$totalsLine")" $ltrl
		echo -e "$(echo "$hrlyData" | grep -v "\"hour\":\"$hr\"")\n${intervalTraffic//,0,0\"/\"}\n${totalsLine//,0,0\"/\"}" > "$hourlyDataFile"
		echo -e "\n//$hr:$(printf %02d $(( ${mm#0} - ${_updateTraffic:-4} )))->$hr:$mm ($vnx)\n${intervalTraffic//,0,0\"/\"}\n${totalsLine//,0,0\"/\"}" >> "$rawtraffic_hr"
	else
		Send2Log "GetTraffic ($hr:$mm): No traffic" 1
		local str="Totals({ \"hour\":\"$hr\""
		echo -e "$(echo "$hrlyData" | grep -v "$str")\n${totalsLine//,0,0\"/\"}" > "$hourlyDataFile"
		echo -e "\n//$hr:$(printf %02d $(( ${mm#0} - ${_updateTraffic:-4} )))->$hr:$mm ($vnx)\n//No traffic" >> "$rawtraffic_hr"
	fi

	sed -i "s~var hourly_updated.\{0,\}$~var hourly_updated=\"$_ds $hr:$mm\"~" "$hourlyDataFile"
	sed -i "s~var serverUptime.\{0,\}$~var serverUptime=\"$currentUptime\"~" "$hourlyDataFile"

	cp "$hourlyDataFile" "$_path2CurrentMonth"
	cp "$tmpLastSeen" "${_lastSeenFile}" 
	ChangePath '_uptime' "$currentUptime"
}
