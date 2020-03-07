#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# updates the data for the live tab
# run: by cron
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - added current traffic to the output file
# 2019-12-23: 4.0.5 - no changes 
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/shared.sh"
source "${d_baseDir}/includes/traffic.sh"

Send2Log "Running update-live-data"

CurrentConnections_0()
{ #_doCurrConnections=0 --> do nothing, the option is disabled
	return
}

CurrentConnections_1()
{ #_doCurrConnections=1

	IP6Enabled(){
		echo "$(ip6tables -L "$YAMON_IPTABLES" "$vnx" | grep -v RETURN | awk '{ print $2,$7,$8 }' | grep "^[1-9]")"
	}
	NoIP6(){
		echo ''
	}

	Send2Log "Running CurrentConnections_1 --> $_liveFilePath"

	ArchiveLiveUpdates_0()
	{ #_doArchiveLiveUpdates=0 --> do nothing, the option is disabled
		return
	}
	ArchiveLiveUpdates_1()
	{ #_doArchiveLiveUpdates=1
		local dpct=$(df $d_baseDir | grep "^/" | awk '{print $5}')
		local dspace=$(printf %02d $(echo "${dpct%\%} "))

		if [ "$dspace" -lt '90' ] ; then
			cat "$_liveFilePath" >> $_liveArchiveFilePath
		else
			Send2Log "ArchiveLiveUpdates_: skipped because of low disk space: $dpct" 3
		fi
	}
	
	#to-do - grab the iptables data and send along with the live data
	local vnx='-vnx'
	local ip4t=$(iptables -L "$YAMON_IPTABLES" "$vnx" | grep -v RETURN | awk '{ print $2,$8,$9 }' | grep "^[1-9]")
	local ip6t="$ip6tablesFn"
	local ipt="$ip4t\n$ip6"
	local macIP=$(cat "$macIPFile")
	
	echo -e "\n/*current traffio by device:*/" >> $_liveFilePath
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
		if [ "$_generic_ipv4" == "$ip" ] || [ "$_generic_ipv6" == "$ip" ] ; then
			ipt=$(echo -e "$ipt" | grep -v "$fl")
		else
			local do=$(echo "$ipt" | grep -E "($_generic_ipv4|$_generic_ipv6) $tip\b" | cut -d' ' -f1)
			local up=$(echo "$ipt" | grep -E "$tip ($_generic_ipv4|$_generic_ipv6)" | cut -d' ' -f1)
			local mac=$(echo "$macIP" | grep $tip | awk '{print $1}')
			[ -z "$mac" ] && mac=$(GetMACbyIP "$tip")
			echo "curr_users4({id:'$mac-$ip',down:'${do:-0}',up:'${up:-0}'})" >> $_liveFilePath
			ipt=$(echo -e "$ipt" | grep -v "$tip")
		fi
	done
	
	local ddd=$(awk "$_conntrack_awk" "$_conntrack")
	echo -e "\n/*current connections by ip:*/" >> $_liveFilePath
	local err=$(echo "${ddd%,}]" 2>&1 1>> $_liveFilePath)
	#Send2Log "curr_connections >>>\n$ddd" 0
	[ -n "$err" ] && Send2Log "ERROR >>> doliveUpdates:  $(IndentList "$err")" 3
	$doArchiveLiveUpdates
}

loads=$(cat /proc/loadavg | cut -d' ' -f1,2,3 | tr -s ' ' ',')
Send2Log ">>> loadavg: $loads"

echo -e "var last_update='$_ds $_ts'${_nl}serverload($loads)" > $_liveFilePath

$doCurrConnections

LogEndOfFunction
