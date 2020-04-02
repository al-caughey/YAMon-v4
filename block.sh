#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# utility functions used by install and setup
#
# History
# 2020-01-26: 4.0.7 - replaced hard coded paths (thx tvlz)
# 2020-01-03: 4.0.6 - tweaks for dd-wrt; checking if chain exists
# 2019-12-23: 4.0.5 - updates to allow for blocking duration and IPv6
# 2019-11-24: 4.0.4 - added to root level
# 2019-11-23: development starts on initial v4 release
#
##########################################################################

#NOT USED... as not all firmware variants suppor the days, timestart, timestop options... using cron instead
# iptables -A FORWARD -p tcp -m multiport --dport http,https -o eth0 -i eth1 -m time --timestart 21:30 --timestop 22:30 --days Mon,Tue,Wed,Thu,Fri -j ACCEPT
# iptables -I YAMONv40_test -m time --timestart 21:30 --timestop 22:30 --days Mon,Tue,Wed,Thu,Fri -j DROP
## --weekdays in turris not --days
## NB - timestart &  timestop must be converted to UTC


d_baseDir=$(cd "$(dirname "$0")" && pwd)
showEcho=1
source "${d_baseDir}/includes/shared.sh"
Send2Log "Block - $0 : $1 / $2 / $3 / $4" 1

if [ "$0" == "$1"  ] ; then
	chainNames=${2:-Unknown}
	status=${3:-DROP}
	[ "$status" == 'DROP' ] && comment='Currently blocked by YAMon' || comment=''

	duration=${4:-0}
	restrictionName=$5
else
	chainNames=${1:-Unknown}
	status=${2:-DROP}
	[ "$status" == 'DROP' ] && comment='Currently blocked by YAMon' || comment=''

	duration=${3:-0}
	restrictionName=$4
fi
if [ "$duration" == 0 ] ; then
	Send2Log "Block: $restrictionName change '$chainNames' to '$status'" 2
else
	Send2Log "Block: $restrictionName change '$chainNames' to '$status' for $duration min" 2
fi

IFS=$','
for ch in $chainNames ; do
	ch=$(echo $ch | sed "s~[^a-z0-9]~~ig")
	if [ -z "$(iptables -L | grep Chain | grep "YAMONv40_${ch}")" ] ; then
		Send2Log "Block: Chain YAMONv40_${ch} does not exist in iptables" 1
	else
		if [ "$_firmware" == "0" ] ; then
			iptables -R YAMONv40_${ch} 1 -j ${status}
		else
			iptables -R YAMONv40_${ch} 1 -j ${status} -m comment --comment "$comment"
		fi
		Send2Log "Block: iptables - status of chain 'YAMONv40_${ch}' set to '${status}' $(IndentList $(iptables -L YAMONv40_${ch} | grep 'anywhere'))" 2
	fi
	if [ "$ip6Enabled" == '1' ] ; then
		if [ -z "$(ip6tables -L | grep Chain | grep "YAMONv40_${ch}")" ] ; then
			Send2Log "Block: Chain YAMONv40_${ch} does not exist in ip6tables" 1
		else
			ip6tables -R YAMONv40_${ch} 1 -j ${status}
			Send2Log "Block: ip6tables - status of chain 'YAMONv40_${ch}' set to '${status}' $(IndentList $(ip6tables -L YAMONv40_${ch} | grep 'anywhere'))" 2
		fi
	fi
done
unset IFS
Send2Log "Block: done" 0
[ "$duration" == 0 ] && return
Send2Log "[Un]blocking $chainNames in $duration minutes" 2
[ "$status" == 'DROP' ] && newStatus='RETURN' || newStatus='DROP'
sleep $((duration * 60)) && ${d_baseDir}/block.sh "$chainNames" "$newStatus" &

Send2Log "Block: done after $duration" 0
