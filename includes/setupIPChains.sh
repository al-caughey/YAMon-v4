##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# functions to define chains in iptables & optionally ip6tables
#
# History
# 2020-03-20: 4.0.7 - added wait option ( -w -W1) to commands that add entries in iptables; 
#                   - then added _iptablesWait 'cause not all firmware variants support iptables -w...
# 2020-01-03: 4.0.6 - added check for _logNoMatchingMac in SetupIPChains
# 2019-12-23: 4.0.5 - no changes
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
# To Do:
#	* allow comma separated list of guest interfaces
#	* add ip6 addresses for interfaces
#
##########################################################################

_PRIVATE_IP4_BLOCKS='10.0.0.0/8,172.16.0.0/12,192.168.0.0/16'
_PRIVATE_IP6_BLOCKS='fc00::/7,ff02::/7'
_LOCAL_IP4='255.255.255.255,224.0.0.1,127.0.0.1'
_LOCAL_IP6=''

SetupIPChains(){

    CheckChains(){
		local chain="$YAMON_IPTABLES$ch"
        local ce=$(echo "$ipchains" | grep "\b$chain\b")
		Send2Log "CheckChain: $chain --> '$ce'" 
        if [ -z "$ce" ] ; then
            Send2Log "CheckChains: Adding $chain in $cmd" 2
            eval $cmd -N $chain "$_iptablesWait"
        else 
            Send2Log "CheckChain: $chain exists in $cmd" 1
        fi
    }

	CheckTables()
	{
		local rule="${YAMON_IPTABLES}Entry"
		local foundRuleinChain=$(eval $cmd -nL "$tbl" | grep -ic "\b$rule\b")

		if [ "$foundRuleinChain" == "1" ] ; then
			Send2Log "CheckTables: '$cmd' rule $rule exists in chain $tbl" 1
			return
		elif [ "$foundRuleinChain" -eq "0" ]; then
			Send2Log "CheckTables: Created '$cmd' rule $rule in chain $tbl" 2
			eval $cmd -I "$tbl" -j "$rule" "$_iptablesWait"
			return
		fi
		
		#its unlikely you should get here... but added defensively
		Send2Log "CheckTables: Found $foundRuleinChain instances of '$cmd' $rule in chain $tbl... deleting entries individually rather than flushing!" 3
		local i=1
		while [  "$i" -le "$foundRuleinChain" ]; do
			local dup_num=$($cmd -nL "$tbl" --line-numbers | grep -m 1 -i "\b$rule\b" | cut -d' ' -f1)
			eval $cmd -D "$tbl" $dup_num "$_iptablesWait"
			i=$(($i+1))
		done
		eval $cmd -I "$tbl" -j "$rule" "$_iptablesWait"
	}
	
    AddPrivateBlocks(){
        $cmd -F "$YAMON_IPTABLES"
        $cmd -F "$ent"
        $cmd -F "$loc"
		Send2Log "AddPrivateBlocks: $cmd / '$YAMON_IPTABLES' / '$ent' / '$loc' / $ip_blocks" 1
    	IFS=$','
        for iprs in $ip_blocks
        do
            for iprd in $ip_blocks
            do
				if [ "$_firmware" -eq "0" ] && [ "$cmd" == 'ip6tables' ] ; then
					eval $cmd -I "$ent" -j "RETURN" -s $iprs -d $iprd "$_iptablesWait"
					eval $cmd -I "$ent" -j "$loc" -s $iprs -d $iprd "$_iptablesWait"
				else
					eval $cmd -I "$ent" -g "$loc" -s $iprs -d $iprd "$_iptablesWait"
				fi
			done
        done
        eval $cmd -A "$ent" -j "${YAMON_IPTABLES}" "$_iptablesWait"
		eval $cmd -I "$loc" -j "RETURN" "$_iptablesWait"
			
		Send2Log "chains --> $cmd / $YAMON_IPTABLES --> $(IndentList "$($cmd -L -vx | grep $YAMON_IPTABLES | grep Chain)")"
    }

    AddLocalIPs(){
		Send2Log "AddLocalIPs: $cmd / '$YAMON_IPTABLES' / '$ent' / '$loc' / $ip_addresses" 1
    	IFS=$','
        for ip in $ip_addresses
        do
			if [ "$_firmware" -eq "0" ] && [ "$cmd" == 'ip6tables' ] ; then
				eval $cmd -I "$ent" -j "RETURN" -s $ip "$_iptablesWait"
				eval $cmd -I "$ent" -j "RETURN" -d $ip "$_iptablesWait"
				eval $cmd -I "$ent" -j "$loc" -s $ip "$_iptablesWait"
				eval $cmd -I "$ent" -j "$loc" -d $ip "$_iptablesWait"
			else
				eval $cmd -I "$ent" -g "$loc" -s $ip "$_iptablesWait"
				eval $cmd -I "$ent" -g "$loc" -d $ip "$_iptablesWait"
			fi	
        done
    }

	#Main body of function
	local commands='iptables'
	[ -n "$ip6Enabled" ] && commands='iptables,ip6tables'

	local chains=",Entry,Local"
	local tables="FORWARD,INPUT,OUTPUT"
	
	local loc="${YAMON_IPTABLES}Local"
	local ent="${YAMON_IPTABLES}Entry"

	IFS=$','
	for cmd in $commands
	do
		Send2Log "SetupIPChains --> $cmd" 1
		local ipchains=$(eval "$cmd" -L | grep "Chain $YAMON_IPTABLES")

		for ch in $chains
		do
			CheckChains
		done
			
		if [ "$cmd" == 'iptables' ] ; then
			local ip_blocks="$_PRIVATE_IP4_BLOCKS"
			local ip_addresses="$_LOCAL_IP4"
		else
			local ip_blocks="$_PRIVATE_IP6_BLOCKS"
			local ip_addresses="$_LOCAL_IP6"
		fi
		
		AddPrivateBlocks
		AddLocalIPs
		
		for tbl in $tables
		do
			CheckTables
		done
		
		if [ "${_logNoMatchingMac:-0}" -eq "1" ] ; then
			eval $cmd -A "$YAMON_IPTABLES" -j LOG --log-prefix "YAMon: " "$_iptablesWait"
		else
			eval $cmd -A "$YAMON_IPTABLES" -j RETURN			
		fi
		
	done

}
AddNetworkInterfaces(){
	Send2Log "AddNetworkInterfaces:" 1
	listofInterfaces=$(ls /sys/class/net)
	#[ -z "$listofInterfaces" ] && "$(ifconfig | grep HWaddr | awk '{print $1}')"
	local re_mac='([a-f0-9]{2}:){5}[a-f0-9]{2}'
	IFS=$'\n' 
	interfaceList=''
	for inf in $listofInterfaces
	do
		ifc=$(ifconfig $inf)
		mac=$(echo "$ifc" | grep -o 'HWaddr.*$' | cut -d' ' -f2 | tr "[A-Z]" "[a-z]")
		[ -z "$mac" ] && continue
		if [ -z "$(echo "$mac" | grep -Ei "$re_mac")" ] ; then
			Send2Log "AddNetworkInterfaces: bad mac --> $mac from $ifc" 1 
			continue
		fi
		inet4=$(echo "$ifc" | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
		inet6=$(echo "$ifc" | grep 'inet6 addr'| awk '{print $3}')
		[ -z "$inet4" ] && [ -z "$inet6" ] && continue
		iplist=$(echo -e "$inet4\n$inet6")
		Send2Log "AddNetworkInterfaces: $inf --> $mac $(IndentList "$iplist")" 1
		for ip in $iplist
		do
			[ -z "$ip" ] && continue
			CheckMAC2IPinUserJS "$mac" "$ip" "$inf"
			CheckMAC2GroupinUserJS "$mac" 'Interfaces'
			CheckIPTableEntry "$ip" "Interfaces"
		done
		interfaceList="$interfaceList,$inf"
	done
	interfaceList=${interfaceList#,}
	AddEntry "_interfaces" "$interfaceList"
	
	IFS=$'\n'
	pnd=$(cat "/proc/net/dev" | grep -E "${interfaceList//,/|}")
	for line in $pnd
	do
		ifn=$(echo "$line" | awk '{ print $1 }' | sed -e 's~-~_~' -e 's~:~~')
		AddEntry "interface_${ifn}" "$(echo "$line" | awk '{ print $10","$2 }')"
	done

	CheckMAC2IPinUserJS "$_generic_mac" "$_generic_ipv4" "No Matching Device"
	[ "$ip6Enabled" == '1' ] && CheckMAC2IPinUserJS "$_generic_mac" "$_generic_ipv6" "No Matching Device"
	CheckMAC2GroupinUserJS "$_generic_mac" "$_defaultGroup"
}
