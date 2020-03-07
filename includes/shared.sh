##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# various utility functions (shared between one or more scripts)
#
# History
# 2020-01-26: 4.0.7 - added static leases for Tomato (thx tvlz)
#                   - added wait option ( -w -W1) to commands that add entries in iptables
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - changed loglevel of start messages in logs
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

_ds=$(date +"%Y-%m-%d")
_ts=$(date +"%T")
_generic_mac="un:kn:ow:n0:0m:ac"

source "${d_baseDir}/includes/version.sh"
source "${d_baseDir}/config.file"
source "${d_baseDir}/includes/paths.sh"
source "$d_baseDir/strings/${_lang:-en}/strings.sh"

tmplog='/tmp/yamon/'
[ -d "$tmplog" ] || mkdir -p "$tmplog"
tmplogFile='/tmp/yamon/yamon.log'

[ -z "$showEcho" ] && exec >> $tmplogFile 2>&1 # send error messages to the log file as well!

[ -f "$_usersFile" ] && _currentUsers=$(cat "$_usersFile")

Send2Log(){
	[ "${2:-0}" -lt "${_loglevel:-0}" ] && return
	echo -e "<section class='ll${2:-0}'><article class='dt'>$(date +"%T")</article><article class='msg'>$1</article></section>" >> "$tmplogFile"
}

IndentList(){
	echo '<ul>'
	echo -e "$1" | grep -Ev "^\s{0,}$" | sed -e "s~^\s\{0,\}~<li>~Ig" 
	echo '</ul>'
}

Send2Log "${0##$d_baseDir/} - start" 0

SetRenice(){
	# if firmware supports renice, set the value
	#Send2Log "SetRenice: renice 10 $$" 1
	renice 10 $$
}
NoRenice(){
	# if firmware doesn't support renice
	#Send2Log "NoRenice" 1
	return
}

$_setRenice

LogEndOfFunction(){
	Send2Log "${0##$d_baseDir/} - end" $1
}

AddEntry(){
	local param="${1//./_}"
	local value="$2"

	local pathsFile="${3:-${d_baseDir}/includes/paths.sh}"
	local existingValue=$(cat "$pathsFile" | grep "$param=.\{0,\}$")
	if [ -z "$existingValue" ] ; then
		Send2Log "AddEntry: adding value --> \`$param\`='$value' in$pathsFile " 1
		echo $param=\'$value\' >> "${d_baseDir}/includes/paths.sh"
	else
		Send2Log "ChangePath: changing value of \`$param\` to $value (prior $existingValue) in $pathsFile" 1
		sed -i "s~^$existingValue~$param='$value'~" "$pathsFile"
	fi
}
ChangePath(){
	#changes a value in /includes/paths.sh
	AddEntry "$1" "$2" "$3"
}
CheckGroupChain(){
	Send2Log "CheckGroupChain: $1 /  $2 " 0
	local cmd=$1
	local groupName=${2:-Unknown}
	local groupChain="${YAMON_IPTABLES}_$(echo $groupName | sed "s~[^a-z0-9]~~ig")"
	if [ -z "$($cmd -L | grep '^Chain' | grep "$groupChain\b")" ] ; then
		Send2Log "CheckGroupChain: Adding group chain to iptables: $groupChain  " 2
		$cmd -N "$groupChain" -w -W1
		$cmd -A "$groupChain" -j "RETURN" -w -W1
	fi
}
CheckIPTableEntry(){

	Send2Log "CheckIPTableEntry: $1 /  $2 " 0
	
	local ip=$1
	local groupName=${2:-Unknown}
	local chain="$YAMON_IPTABLES"
	Send2Log "CheckIPTableEntry: ip=$ip / cmd=$cmd / chain=$YAMON_IPTABLES " 0
	
	re_ip4="([0-9]{1,3}\.){3}[0-9]{1,3}"	
	#if [ -n "$(echo $ip | egrep "$re_ip4")" ] ; then # simplistically matches IPv4
	if [ -n "$(echo $ip | grep -E "$re_ip4")" ] ; then # simplistically matches IPv4
		local cmd='iptables'
		local g_ip='0.0.0.0/0'
	else
		[ -z "$ip6Enabled" ] && Send2Log "CheckIPTableEntry: skipping ip6tables check for $ip as IPv6 is not enabled" 1 && return
		local cmd='ip6tables'
		local g_ip='::/0'
	fi
	Send2Log "CheckIPTableEntry: checking $cmd for $ip"
	
	ClearDuplicateRules(){
		local n=1
		while [ true ]; do
			[ -z "$ip" ] && break
			local dup_num=$($cmd -L "$YAMON_IPTABLES" -n --line-numbers | grep -m 1 -i "\b$ip\b" | cut -d' ' -f1)
			[ -z "$dup_num" ] && break
			$cmd -D "$YAMON_IPTABLES" $dup_num -w -W1
			n=$(( $n + 1 ))
		done
		Send2Log "ClearDuplicateRules: removed $n duplicate entries for $ip" 0
	} 
	AddIP(){
		local groupChain="${YAMON_IPTABLES}_$(echo $groupName | sed "s~[^a-z0-9]~~ig")"
		Send2Log "AddIP: $cmd $YAMON_IPTABLES $ip --> $groupChain (firmware: $_firmware)" 0
		if [ "$_firmware" -eq "0" ] && [ "$cmd" == 'ip6tables' ] ; then
			$cmd -I "$YAMON_IPTABLES" -j "RETURN" -s $ip -w -W1
			$cmd -I "$YAMON_IPTABLES" -j "RETURN" -d $ip -w -W1
			$cmd -I "$YAMON_IPTABLES" -j "$groupChain" -s $ip -w -W1
			$cmd -I "$YAMON_IPTABLES" -j "$groupChain" -d $ip -w -W1
		else
			$cmd -I "$YAMON_IPTABLES" -g "$groupChain" -s $ip -w -W1
			$cmd -I "$YAMON_IPTABLES" -g "$groupChain" -d $ip -w -W1
			Send2Log "AddIP: $cmd -I "$YAMON_IPTABLES" -g "$groupChain" -s $ip"
		fi
	}
	
	[ "$ip" == "$g_ip" ] && return
	local tip="\b${ip//\./\\.}\b"
	local nm=$($cmd -L "$YAMON_IPTABLES" -n | grep -ic "$tip")
		
	if [ "$nm" -eq "2" ] || [ "$nm" -eq "4" ] ; then  #correct number of entries
		Send2Log "CheckIPTableEntry: $nm matches for $ip in $cmd / $YAMON_IPTABLES" 
		return
	fi
	
	CheckGroupChain $cmd $groupName
	
	if [ "$nm" -eq "0" ]; then
		Send2Log "CheckIPTableEntry: no match for $ip in $cmd / $YAMON_IPTABLES"
	else
		Send2Log "CheckIPTableEntry: Incorrect number of rules for $ip in $cmd / $YAMON_IPTABLES -> $nm... removing duplicates\n\t$cmd -L "$YAMON_IPTABLES" | grep -ic "$tip"" 3
		ClearDuplicateRules
	fi
	AddIP
}
UpdateLastSeen(){
	local id="$1"
	local tls="$2"

	local lsd="$_ds $tls"
	Send2Log "UpdateLastSeen:  Updating last seen for '$id' to '$lsd'" 0
	echo -e "lastseen({ \"id\":\"$id\", \"last-seen\":\"$lsd\" })\n$(cat "$tmpLastSeen" | grep -e "^lastseen({.*})$" | grep -v "$id")" > "$tmpLastSeen"
}
GetField()
{	#returns just the first match... duplicates are ignored
	local result=$(echo "$1" | grep -io -m1 "$2\":\"[^\"]\{1,\}" | cut -d\" -f3)
	echo "$result"
	[ -n "$result" ] && Send2Log "GetField: $2='$result' in \`$1\`" && return
	[ -z "$result" ] && [ -z "$1" ] && Send2Log "GetField: field '$2' not found because the search string was empty (\`$1\`)" 1 && return
	[ -z "$result" ] && Send2Log "GetField: field '$2' not found in \`$1\`" 1
}
UsersJSUpdated(){
	Send2Log "UsersJSUpdated: users_updated changed to '$_ds $_ts'" 2
	sed -i "s~users_updated=\"[^\"]\{0,\}\"~users_updated=\"$_ds $_ts\"~" "$_usersFile"
}
UpdateField(){
	local cl="$1" #current line of text
	local wf="$2" #which field to update
	local nv="$3" #new value
	local result=$(echo "$cl" | sed -e "s~\"$wf\":\"[^\"]\{0,\}\"~\"$wf\":\"$nv\"~" -e "s~\"updated\":\"[^\"]\{0,\}\"~\"updated\":\"$_ds $_ts\"~")
	[ -z "$result" ] && Send2Log "UpdateField: replacement of $wf failed" 2
	echo "$result"
}
GetDeviceName(){
	local mac="$1"
	NullFunction(){ #do nothing
		echo ''
	}

	DNSMasqConf(){
		local mac="$1"
		local result=$(echo "$(cat $_dnsmasq_conf | grep -i "dhcp-host=")" | grep -i "$mac" | cut -d, -f$deviceNameField)
		Send2Log "DNSMasqConf: result=$result" 0
		echo "$result"
	}
	DNSMasqLease(){
		local mac="$1"
		local dnsmasq=''
		[ -f "$_dnsmasq_leases" ] && local dnsmasq=$(cat "$_dnsmasq_leases")
		local result=$(echo "$dnsmasq" | grep -i "$mac" | tr '\n' ' / ' | cut -d' ' -f4)
		Send2Log "DNSMasqLease: result=$result" 0
		echo "$result"
	}
	StaticLeases_DDWRT(){
		local mac="$1"
		local nvr=$(nvram show 2>&1 | grep -i "static_leases=")
		local result=$(echo "$nvr" | grep -io "$mac[^=]*=.\{1,\}=.\{1,\}=" | cut -d= -f2)
		Send2Log "StaticLeases_DDWRT: result=$result" 0
		echo "$result"
	}
	StaticLeases_OpenWRT(){
		local mac="$1"
		# thanks to Robert Micsutka for providing this code & easywinclan for suggesting & testing improvements!
		local result=''
		local ucihostid=$(uci show dhcp | grep -i $mac | cut -d. -f2)
		[ -n "$ucihostid" ] && local result=$(uci get dhcp.$ucihostid.name)
		Send2Log "StaticLeases_OpenWRT: result=$result " 0
		echo "$result"
	}
	StaticLeases_Merlin(){
		local mac="$1"
		#thanks to Chris Dougherty for providing this code
		local nvr=$(nvram show 2>&1 | grep -i "dhcp_staticlist=")
		local nvrt=$nvr
		local nvrfix=''
		while [ "$nvrt" ] ;do
			iter=${nvrt%%<*}
			nvrfix="$nvrfix$iter="
			[ "$nvrt" = "$iter" ] && \
				nvrt='' || \
				nvrt="${nvrt#*<}"
		done
		nvr=${nvrfix//>/=}
		local result=$(echo "$nvr" | grep -io "$mac[^=]*=.\{1,\}=.\{1,\}=" | cut -d= -f3)
		Send2Log "StaticLeases_Merlin: result=$result " 0
		echo "$result"
	}
	StaticLeases_Tomato(){
		local mac="$1"
		#thanks to Tvlz for providing Tomato Nvram settings
		local nvr=$(nvram show 2>&1 | grep -i "dhcpd_static=")
		local nvrt=$nvr
		local nvrfix=''
		while [ "$nvrt" ] ;do
			iter=${nvrt%%<*}
			nvrfix="$nvrfix$iter="
			[ "$nvrt" = "$iter" ] && \
				nvrt='' || \
				nvrt="${nvrt#*<}"
		done
		nvr=${nvrfix//>/=}
		local result=$(echo "$nvr" | grep -io "$mac[^=]*=.\{1,\}=.\{1,\}=" | cut -d= -f3)
		Send2Log "StaticLeases_Tomato: result=$result " 0
		echo "$result"
	}
	Send2Log "GetDeviceName: $1 $2" 0
	#check first in static leases
	local dn=`$nameFromStaticLeases "$mac"`
	if [ -n "${dn/$/}" ] ; then
		Send2Log "GetDeviceName: found device name $dn for $mac in static leases ($nameFromStaticLeases)" 0 
		echo "$dn" 
		return
	fi
	Send2Log "GetDeviceName: No device name for $mac in static leases ($nameFromStaticLeases)" 0
	
	#then in DNSMasqConf
	dn=`$nameFromDNSMasqConf "$mac"`
	if [ -n "${dn/$/}" ] ; then
		Send2Log "GetDeviceName: found device name $dn for $mac in $_dnsmasq_conf" 0 
		echo "$dn" 
		return
	fi
	Send2Log "GetDeviceName: No device name for $mac in in $_dnsmasq_conf ($nameFromDNSMasqConf)" 0
	
	#finally in DNSMasqLease
	dn=`$nameFromDNSMasqLease "$mac"`
	if [ -n "${dn/$/}" ] ; then
		Send2Log "GetDeviceName: found device name $dn for $mac in $_dnsmasq_leases" 0 
		echo "$dn" 
		return
	fi
	Send2Log "GetDeviceName: No device name for $mac in in $_dnsmasq_leases ($nameFromDNSMasqLease)" 0
	
	#Dang... no matches
	local big=$(cat "$_usersFile" | grep -e "^mac2ip({.*})$" | grep -o "\"$_defaultDeviceName-[^\"]\{0,\}\"" | sort | tail -1 | tr -d '"' | cut -d- -f2)
	local nextnum=$(printf %02d $(( $(echo "${big#0} ")+ 1 )))
	echo "$_defaultDeviceName-$nextnum"
	Send2Log "GetDeviceName: did not find name for  $mac... defaulting to $_defaultDeviceName-$nextnum" 0
}

CheckMAC2GroupinUserJS(){
	Send2Log "CheckMAC2GroupinUserJS:  $1 $2" 2
	local m=$1
	local gn=${2:-${_defaultGroup:-${_defaultOwner:-Unknown}}}

	ChangeMACGroup(){
		Send2Log "ChangeMACGroup: group names do not match! $gn !== $cgn " 2
		local newLine=$(UpdateField "$matchesMACGroup" 'group' "$gn")
		local groupChain="${YAMON_IPTABLES}_$(echo $gn | sed "s~[^a-z0-9]~~ig")"
		sed -i "s~$matchesMACGroup~$newLine~" $_usersFile
		#To do - change entries in ip[6]tables
		# iptables -E YAMONv40_Interfaces2 YAMONv40_Interfaces
		local matchingMACs=$(cat "$_usersFile" | grep -e "^mac2ip" | grep "\"active\":\"1\"")
		IFS=$'\n'
		for line in $matchingMACs ; do
			[ -z "$line" ] && continue
			local id=$(GetField $line 'id')
			[ -z "$id" ] && continue
			local mm=$(echo "$id" | cut -d'-' -f1)
			local ii=$(echo "$id" | cut -d'-' -f2)

			re_ip4="([0-9]{1,3}\.){3}[0-9]{1,3}"	
			if [ -n "$(echo $ip | grep -E "$re_ip4")" ] ; then # simplistically matches IPv4
				local cmd='iptables'
			else
				local cmd='ip6tables'
			fi
			Send2Log "ChangeMACGroup: changing chain destination for $ii in $cmd ($gn)" 2

			local matchingRules=$($cmd -L ${YAMON_IPTABLES} -n --line-numbers | grep "\b${ii//\./\\.}\b")
			for rule in $matchingRules ; do
				[ -z "$rule" ] && continue
				local ln=$(echo $rule | awk '{print $1}')
				$cmd -R ${YAMON_IPTABLES} $ln -j $groupChain -w -W1
				Send2Log "ChangeMACGroup: changing destination of $rule to $gn" 2
			done
		done
		UsersJSUpdated
	}
	
	AddNewMACGroup(){
		Send2Log "AddNewMACGroup: adding mac2group entry for $m & $gn" 2
		local newentry="mac2group({ \"mac\":\"$m\", \"group\":\"$gn\" })"
		sed -i "s~//MAC -> Groups~//MAC -> Groups\n$newentry~g" "$_usersFile"
		UsersJSUpdated
	}

	local matchesMACGroup=$(cat "$_usersFile" | grep -e "^mac2group({.*})$" | grep "\"mac\":\"$m\"")
	
	if [ -z "$matchesMACGroup" ] ; then
		AddNewMACGroup
	elif [ "$(echo $matchesMACGroup | wc -l)" -eq 1 ] ; then
		local cgn=$(GetField "$matchesMACGroup" 'group')
		#To do - check that the group names match
		[ -n "$2" ] && [ "$gn" == "$cgn" ] || ChangeMACGroup
	else
		Send2Log "CheckDeviceInUserJS: uh-oh... *$matchesMACGroup* mac2group matches for '$m' in '$_usersFile' --> $(IndentList "$(cat "$_usersFile" | grep -e "^mac2group({.*})$" | grep "\"id\":\"$m\"")")" 2
	fi
}
CheckMAC2IPinUserJS(){
	Send2Log "CheckMAC2IPinUserJS:  $1 $2" 0
	local m=$1
	local i=$2
	local dn=$3
	DeactivatebyIP(){
		Send2Log "DeactivatebyIP:  $i" 0
		local otherswithIP=$(cat "$_usersFile" | grep -e "^mac2ip({.*})$" | grep "\b${i//\./\\.}\b" | grep "\"active\":\"1\"")
		if [ -z "$otherswithIP" ] ; then
			Send2Log "DeactivatebyIP: no active duplicates of $i in $_usersFile" 0 
			return
		fi
		Send2Log "DeactivatebyIP: $(echo "$otherswithIP" | wc -l) active duplicates of $i in $_usersFile" 0
		IFS=$'\n'
		for od in $otherswithIP
		do
			Send2Log "DeactivatebyIP: set active=0 in $od" 0
			local nl=$(UpdateField "$od" 'active' '0')
			local nl=$(UpdateField "$nl" 'updated' "$_ds $_ts")
			sed -i "s~$od~$nl~g" "$_usersFile"
			local changes=1
		done
		[ -n "$changes" ] && UsersJSUpdated
	}
	AddNewMACIP(){
		Send2Log "AddNewMACIP: $m $i $dn" 0
		DeactivatebyIP
		[ -z "$dn" ] && local otherswithMAC=$(cat "$_usersFile" | grep -e "^mac2ip({.*})$" | grep -m1 "$m") #NB - specifically looks for just one match
		if [ -n "$otherswithMAC" ] ; then
			local dn=$(GetField "$otherswithMAC" 'name')
			Send2Log "AddNewMACIP: copying device name '$dn' from $otherswithMAC" 0
			if [ -n "$(echo "$dn" | grep $_defaultDeviceName )" ] ; then
				local ndn=$(GetDeviceName "$m" "$i")
				[ -z "$(echo "$ndn" | grep $_defaultDeviceName )" ] && dn="$ndn"
			fi
		elif [ -z "$dn" ] ; then
			local dn=$(GetDeviceName "$m" "$i")
			Send2Log "Otherwise..." 0
		fi
		Send2Log "AddNewMACIP: adding $newentry to $_usersFile" 0
		local newentry="mac2ip({ \"id\":\"$m-$i\", \"name\":\"${dn:-New Device}\", \"active\":\"1\", \"added\":\"${_ds} ${_ts}\", \"updated\":\"\" })"
		sed -i "s~//MAC -> IP~//MAC -> IP\n$newentry~g" "$_usersFile"
		UpdateLastSeen "$m-$i" "$(date +"%T")"
		UsersJSUpdated
	}
	local matchesMACIP=$(cat "$_usersFile" | grep -e "^mac2ip({.*})$" | grep "\"id\":\"$m-$i\"")
	
	if [ -z "$matchesMACIP" ] ; then
		AddNewMACIP
	elif [ "$(echo $matchesMACIP | wc -l)" -eq 1 ] ; then
		Send2Log "CheckMAC2IPinUserJS: found a unique match for $m-$i"
		[ -z "$dn" ] && return
		# To do: check that the name matches
	else
		Send2Log "CheckMAC2IPinUserJS: uh-oh... *$matchesMACIP* matches for '$m-$i' in '$_usersFile' --> $(IndentList "$(cat "$_usersFile" | grep -e "^mac2ip({.*})$" | grep "\"id\":\"$m-$i\"")")" 2
	fi
}

AddActiveDevices(){
	Send2Log "AddActiveDevices" 0
	local _ActiveIPs=$(cat "$_usersFile" | grep -e "^mac2ip({.*})$" | grep '"active":"1"')
	local _MACGroups=$(cat "$_usersFile" | grep -e "^mac2group({.*})$")
	local currentMacIP=$(cat "$macIPFile")
	local adl=$(echo "$_currentUsers" | grep '"active":"1"')
	IFS=$'\n'
	for device in $_ActiveIPs 
	do
		local id=$(GetField $device 'id')
		local ip=$(echo "$id" | cut -d'-' -f2)
		[ -z "$ip" ] && Send2Log "AddActiveDevices --> IP is null --> $device" && continue
		[ "$_generic_ipv4" == "$ip" ] || [ "$_generic_ipv6" == "$ip" ] && continue
		local mac=$(echo "$id" | cut -d'-' -f1)
		local group=$(GetField "$(echo "$_MACGroups" | grep "$mac")" 'group')
		
		Send2Log "AddActiveDevices --> $id / $mac / $ip / ${group:-Unknown} "
		if [ -z "$(echo "$currentMacIP" | grep "${ip//\./\\.}" )" ] ; then
			Send2Log "AddActiveDevices --> IP $ip does not exist in $macIPFile... added to the list" 0
		else
			Send2Log "AddActiveDevices --> IP $ip exists in $macIPFile... deleted entries $(IndentList "$(echo "$currentMacIP" | grep "${ip//\./\\.}" )")" 2
			echo -e "$macIPList" | grep -Ev "${ip//\./\\.}" > "$macIPFile"
		fi
		Send2Log "AddActiveDevices --> $id added to $macIPFile" 1
		echo "$mac $ip" >> "$macIPFile"
	
		CheckIPTableEntry "$ip" "${group:-Unknown}"
	done
	Send2Log "AddActiveDevices: macipList --> $(IndentList "$(cat "$macIPFile")")"
}

DigitAdd()
{
	Send2Log "DigitAdd - $1 & $2"
	local n1=${1:-0}
	local n2=${2:-0}
	if [ "${#n1}" -lt "${_max_digits:-12}" ] && [ "${#n1}" -lt "${_max_digits:-12}" ] ; then
		echo $(($n1+$n2))
		return
	fi
	local l1=${#n1}
	local l2=${#n2}
	local carry=0
	local total=''
	while [ "$l1" -gt "0" ] || [ "$l2" -gt "0" ]; do
		d1=0
		d2=0
		l1=$(($l1-1))
		l2=$(($l2-1))
		[ "$l1" -ge "0" ] && d1=${n1:$l1:1}
		[ "$l2" -ge "0" ] && d2=${n2:$l2:1}
		s=$(($d1+$d2+$carry))
		sum=$(($s%10))
		carry=$(($s/10))
		total="$sum$total"
	done
	[ "$carry" -eq "1" ] && total="$carry$total"
	echo ${total:-0}
	Send2Log "DigitAdd: $1 + $2 = $total"
}
CheckIntervalFiles(){
# create the data directory
	[ -f "$_intervalDataFile" ] && return
	if [ ! -d "$_path2CurrentMonth" ] ; then
		mkdir -p "$_path2CurrentMonth"
		Send2Log "CheckIntervalFiles: create directory: $_path2CurrentMonth" 1
	fi
	Send2Log "CheckIntervalFiles: create interval file: $_intervalDataFile" 1
	echo "var monthly_created=\"${_ds} ${_ts}\"
	var monthly_updated=\"${_ds} ${_ts}\"
	var monthlyDataCap=\"$_monthlyDataCap\"
	var monthly_total_down=\"0\"	// 0 GB
	var monthly_total_up=\"0\"	// 0 GB
	var monthly_unlimited_down=\"0\"	// 0 GB
	var monthly_unlimited_up=\"0\"	// 0 GB
	var monthly_billed_down=\"0\"	// 0 GB
	var monthly_billed_up=\"0\"	// 0 GB
	" >> $_intervalDataFile
}
