#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# converts user.js to the new format used by YAMon v4
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

mac2ipTemplate='printf "mac2ip({\"id\":\"%s\",\"name\":\"%s\",\"added\":\"%s\",\"updated\":\"%s\",\"last-seen\":\"%s\"})"'
re_ip4="([0-9]{1,3}\.){3}[0-9]{1,3}"

nis=$(date +"%s")   #now in seconds
tl=$((30*24*3600))  #timelimit for active--> 1 month

AddIPs2MAC2IP(){

	local ip="$1"
	IFS=$','
	for i in $ip
	do
		local lsis=$(date -d "${lastseen:-2007-01-01}" +"%s")
		[ $(($nis - $lsis)) -gt $tl ] && active=0 || active=1

		echo "mac2ip({\"id\":\"$mac-$ip\",\"name\":\"$name\",\"active\":\"$active\",\"added\":\"$added\",\"updated\":\"$updated\"})" >> "${tmplog}mac2ip.txt"
		[ -z "$lastseen" ] && lastseen="$updated"
		[ -z "$lastseen" ] && lastseen="$added"
		echo "lastseen({\"id\":\"$mac-$ip\",\"last-seen\":\"$lastseen\"})" >> "$tmpLastSeen"
		
	done
	unset IFS
}
echo "_usersFile=$_usersFile"
_currentUsers=$(cat "$_usersFile")
#echo "_currentUsers=$(IndentList "$_currentUsers")"

[ -n "$(echo "$_currentUsers" | grep "var users_version")" ] && echo "No need to update your users.js file" && return

nfn=${_usersFile/.js/-${_ds}.js}
echo "Backing up $_usersFile to $nfn"
cp "$_usersFile" "$nfn"

header=$(echo "$_currentUsers" | grep -v "^ud_a" | grep -v 'users_updated')
header="var users_version=\"YAMon v4\"\n$header\nusers_updated=\"${_ds} ${_ts}\""

devices=$(echo "$_currentUsers" | grep "^ud_a")
[ -z "$devices" ] && echo "No legacy entries... " && return
IFS=$'\n'
m2g_f="${tmplog}mac2group.txt"
> "$m2g_f"
m2g=''
for device in $devices
do
	#echo -e "$device\n-----------------"
	mac="$(GetField $device 'mac')"
	ip4="$(GetField $device 'ip')"
	ip6="$(GetField $device 'ip6')"
	echo -n "."
	group="$(GetField $device 'owner')"
	name="$(GetField $device 'name')"
	added="$(GetField $device 'added')"
	updated="$(GetField $device 'updated')"
	lastseen="$(GetField $device 'last-seen')"
	[ -n "$ip4" ] && AddIPs2MAC2IP $ip4
	[ -n "$ip6" ] && AddIPs2MAC2IP $ip6
	[ -z "$(cat "$m2g_f" | grep "$mac")" ] && echo "mac2group({ \"mac\":\"$mac\", \"group\":\"$group\" })" >> $m2g_f
	IFS=$'\n'
done 
echo -e "\n\n Done"
echo -e "$header\n//MAC -> Groups" > $_usersFile
[ -f "$m2g_f" ] && cat "$m2g_f" >> $_usersFile && rm "$m2g_f"

echo -e "\n//MAC -> IP" >> $_usersFile
[ -f "${tmplog}mac2ip.txt" ] && cat "${tmplog}mac2ip.txt" >> $_usersFile && rm "${tmplog}mac2ip.txt"

#echo -e "\n/*Legacy Records\n" >> $_usersFile
#echo -e "$(IndentList "$devices")" >> $_usersFile
#echo -e "\n*/" >> $_usersFile
cp "$tmpLastSeen" "${_lastSeenFile}"

UsersJSUpdated