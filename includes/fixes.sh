##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# various fixed to data files as issues are discovered during beta
#
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - no changes
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

#2019-10-22 --> replace 'New Device-1' with 'New Device-01'
Send2Log "fixes.sh: repair/remove errors found in files" 1

Send2Log "fixes.sh: correct $_defaultDeviceName-# to $_defaultDeviceName-0#"
[ -f "$_usersFile" ] && badDeviceNames=$(cat "$_usersFile" | grep -e "$_defaultDeviceName-[1-9]\"")
if [ -n "$badDeviceNames" ] ; then
	Send2Log "fixes.sh: found bad device names in $_usersFile: $(IndentList "$badDeviceNames")" 2
	sed -i -r "s~($_defaultDeviceName)-([1-9])\"~\1-0\2\"~" "$_usersFile"
fi
Send2Log "fixes.sh: checking for bad entries in $_lastSeenFile"

[ -f "$_lastSeenFile" ] && badlastseen=$(cat "$_lastSeenFile" | grep -v "lastseen({.\{0,\}})$")
if [ -n "$badlastseen" ] ; then
	Send2Log "fixes.sh: found bad entries in $_lastSeenFile: $(IndentList "$badlastseen")" 2
	cat "$_lastSeenFile" | grep -e "lastseen({.*})$" > "$_lastSeenFile"
fi

Send2Log "fixes.sh: fixing }}'} error in hourly files" 2
[ -n "$(find $_path2data | grep 'mac_usage')" ] && sed -i "s~^monthly_updated~var monthly_updated~g" $(find $_path2data | grep 'mac_usage')
[ -n "$(find $_path2data | grep 'hourly')" ] && sed -i "s~}}'}~}}'~g" $(find $_path2data | grep 'hourly')
[ -n "$(find $tmplog | grep 'hourly')" ] && sed -i "s~}}'}~}}'~g" $(find $tmplog | grep 'hourly')

FixMonthlyUsageFile(){
	[ -n "$(find $_path2data | grep 'mac_usage')" ] && sed -i "s~^monthly_updated~var monthly_updated~g" $(find $_path2data | grep 'mac_usage')
	source "${d_baseDir}/includes/dailytotals.sh"
	local filelist=$(find $_path2data | grep 'hourly')
	local usagefiles=$(find $_path2data | grep 'mac_usage.js')
	IFS=$'\n'
	for uf in $usagefiles ; do
		cp $uf "${uf/.js/.old}"
		echo "$(cat "$uf" | grep "^var")" > $uf
		local dir=$(dirname $uf)
		Send2Log "FixMonthlyUsageFile: dir -->$dir" 2
		local filelist=$(find $dir | grep 'hourly')
		for df in $filelist ; do
			local dt=$(echo $df | cut -d'_' -f2 | cut -d'.' -f1)
			Send2Log "FixMonthlyUsageFile:  - $dt -> $df" 1
			CalculateDailyTotals "$dt" "$uf"
		done
	done
}

FixDefaultDeviceNames(){
	Send2Log "FixDefaultDeviceNames"
	#look for entries in users.js with name 'New Device...' and see if there's something better in the DHCP lease file
	local dnsmasq=''
	[ -f "$_dnsmasq_leases" ] && local dnsmasq=$(cat "$_dnsmasq_leases")
	local dhcpl="$(echo "$dnsmasq" | grep -v '*$' | awk '{ print $2 }' | tr "\n" '|')null"
	local ddnl=''
	[ -f "$_usersFile" ] &&  ddnl=$(cat "$_usersFile" | grep -e "^mac2ip({.*})$" | grep "$_defaultDeviceName" | grep -E "$dhcpl")
	IFS=$'\n'
	[ -n "$ddnl" ] && Send2Log "FixDefaultDeviceNames: ddnl--> $(IndentList "$ddnl")" 1
	for wd in $ddnl
	do
		local id=$(GetField "$wd" 'id')
		local on=$(GetField "$wd" 'name')
		local mac=$(echo "$id" | cut -d- -f1)
		local nn=$(echo "$dnsmasq" | grep "$mac" | awk '{ print $4 }')
		Send2Log "FixDefaultDeviceNames: changed device name '$on' to '$nn' for $wd" 2
		local nl=$(UpdateField "$wd" "name" "$nn")
		sed -i "s~$wd~$nl~g" "$_usersFile"
		local changed=1
	done
	[ -n "$changed" ] && UsersJSUpdated
}
FixDefaultDeviceNames

FixMonthlyUsageFile

sleep 2
echo -e "Fixes complete"
