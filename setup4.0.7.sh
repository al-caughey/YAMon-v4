#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# Script to help set baseline values in config.file for YAMon4.x
#
##########################################################################

# History
# 2020-01-26: 4.0.7 - fixed startup & shutdown code for Tomato (thx tvlz); added CopyDataFiles() to properly copy/rename old data files; added prompt for `_purgeOldFiles` (advanced only)
# 2020-01-03: 4.0.6 - check copied users.js to ensure that entry for users_updated exists; check nvram modelNumber too to get device name
# 2019-12-23: 4.0.5 - added prompt to run fixes; correctly added _firmware, etc to config.file (if missing)
# 2019-11-09: 4.0.2 - improvements for upgrading from v3
# 2019-10-24: 4.0.1 - improvements for fresh install
# 2019-10-09: 4.0.0 - first update for v 4.0

IndentListS(){
	echo -e "$1" | grep -Ev "^\s{0,}$" | sed -e "s~^\s\{0,\}~    ~Ig" 
}
_canClear=$(which clear)
[ -n "$_canClear" ] && clear
CopySettings(){
	local fn=$(echo "$1" | cut -d':' -f2)
	echo -e "\n    Copying settings from '$fn' to '${d_baseDir}/config.file'\n"
	SetupLog "CopySettings: Copying settings from '$fn' to '${d_baseDir}/config.file'" 1
	local settingsList=$(cat "$fn" | grep -e "^_")
	local newSettings=$(cat "${d_baseDir}/default_config.file")
	IFS=$'\n'
	local spaces='                                                                 '
	for line in $settingsList; do
		local vn=$(echo "$line" | cut -d'=' -f1)
		[ "$vn" == "_wwwData" ] && continue #skip _wwwData to avoid clobbering v3 symlink
		local vv=$(echo "$line" | cut -d"=" -f2 | cut -d'#' -f1 | sed -e "s~[\"']~~g" | tr -s ' ')
		[ -z "$(echo "$newSettings"| grep -e "^$vn")" ] && continue
		local txt="$vn='${vv% }'"
		local pad=${spaces:0:$((45 - ${#txt}))}
		newSettings=$(echo "$newSettings" | sed -E "s~^$vn='[^']{0,}'.*#~${txt}${pad}#~")
		SetupLog "CopySettings: setting $txt"
	done
	echo "$newSettings" > "${d_baseDir}/config.file"
}
CheckDataPath(){
	CopyDataFiles(){
		rp=$1
		nd=$2

		SetupLog "Copying YAMon data files
		   from: $rp
		   to:   $nd"

		[ -d $nd ] || mkdir $nd
		
		cp "$rp/users.js" "$nd/users.js"
		fl=$(find "$rp" | grep 'mac_data.js')
		IFS=$'\n'
		n=0
		for fp in $fl ; do
			p=${fp/$rp}
			fn=${p##*/}
			fd=${p%$fn} 
			np=${nd}${fd}${fn/data/usage}
			[ -d ${nd}${fd} ] || mkdir -p ${nd}${fd}
			[ -f "$np" ] || cp "$fp" "$np"
			n=$((n+1))
		done
		SetupLog "Copied $n monthly data files"

		n=0
		#2013-12-31-hourly_data.js --> hourly_2020-02-05.js
		fl=$(find "$rp" | grep 'hourly_data.js')
		IFS=$'\n'
		for fp in $fl ; do
			p=${fp/$rp}
			fn=${p##*/}
			nfn="hourly_${fn/-hourly_data/}"
			fd=${p%$fn} 
			np=${nd}${fd}${nfn}
			[ -f "$np" ] || cp "$fp" "$np"
			n=$((n+1))
		done
		SetupLog "Copied $n hourly data files"

		SetupLog "Number of files in $rp: "$(find "$rp" -type f | wc -l)
		SetupLog "Number of files in $nd: "$(find "$nd" -type f | wc -l)

		ofl=$(find "$rp")
		nfl=$(find "$nd")
		IFS=$'\n'
		n=0
		nm=0
		ncl=''
		for fp in $ofl ; do
			n=$((n+1))
			p=${fp/$rp}
			fn=${p##*/}
			if [ ! -z "$(echo "$nfl" | grep "${fn}")" ] ; then
				continue
			elif [ ! -z "$(echo "$nfl" | grep "${fn/data/usage}")" ] ; then
				continue
			elif [ ! -z "$(echo "$nfl" | grep "hourly_${fn/-hourly_data/}")" ] ; then
				continue
			else
				nm=$((nm+1))
				ncl="$ncl
		$fp"
			fi
		done
		SetupLog "The following $nm files were *not* copied to $nd:\n$(IndentListS "$ncl") "
	}

	if [ "${_dataDir:0:1}" == "/" ] ; then
		local path2data="${_dataDir}" #absolute path to the logs
	else
		local path2data="${d_baseDir}/${_dataDir:-data/}"
	fi
	path2data=${path2data%/}
	if [ ! -d "$path2data" ] ; then
		SetupLog "CheckDataPath: $path2data does not exist" 1
		#oldDataDir=$(find $(dirname "$d_baseDir") -type d -name "YAMon*" | grep -n '')
		oldDataDir=$(find $(dirname "$d_baseDir") -name "YAMon*" | grep -n '') #error -type d not supported by Tomato.
		echo -e "\nCreating your data directory --> '$path2data'"
		if [ -z "$oldDataDir" ] ; then
			SetupLog "CheckDataPath: No prior install... adding an empty folder" 1
			mkdir -p "$path2data"
		else
			Prompt 't_cpd' "Do you want to copy your data directory from your prior installation? " "$yn_y" '1' $zo_r
			local ddn=${path2data##*/}
			
			if [ "$t_cpd" -eq 0 ] ; then
				SetupLog "CheckDataPath: Chose to not copy existing data from $oldDataDir... adding an empty folder" 1
				mkdir -p "$path2data"
			else 
				if [ "$(echo "$oldDataDir" | wc -l)" -eq "1" ] ; then
					local dp=$(echo "$oldDataDir" | cut -d':' -f2)
				else
					local nn='123456789'
					local options=${nn::$(echo "$oldDataDir" | wc -l)}
					Prompt 't_whichData' "Which data directory would you like to copy?\n$(IndentListS "$oldDataDir")" "Pick one of the options: [$options]" "$t_whichInstall" "^[$options]$"
					local dp=$(echo "$oldDataDir" | grep "^$t_whichData:" | cut -d':' -f2)
				fi
				SetupLog "CheckDataPath: Copying existing data from ${dp}/$ddn" 1
				echo -e "\n    Copying from '${dp}/$ddn' to '$path2data'\n    This could take a little while\n"
				CopyDataFiles "${dp}/$ddn" "$path2data" 
				
				if [ -z "$(cat "$path2data/users.js" | grep "^var users_version")" ] ;  then
					SetupLog "CheckDataPath: missing users_version... running up-rev-users-js.sh"
					echo -e "\n    Updating your old version of users.js to the new v4 format.  Once again, this could take a little while\n"
					${d_baseDir}/up-rev-users-js.sh
				fi
			fi
		fi
	fi
}

yn_y="Options:
      \`0\` / \`n\` -> No
      \`1\` / \`y\` -> Yes (*)"
yn_n="Options
      \`0\` / \`n\` -> No (*) 
      \`1\` / \`y\` -> Yes"
zo_r=^[01nNyY]$
zot_r=^[012]$
_qn=0
re_path=^.*$
re_path_slash=^.*/$

d_baseDir="${YAMON%/}"
[ -z "$d_baseDir" ] && d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/prompts.sh"

delay=${1:-5}
[ "$delay" == 'dev' ] && delay=5

source "${d_baseDir}/includes/version.sh"
source "${d_baseDir}/strings/title.inc"
source "${d_baseDir}/strings/${_lang:-en}/strings.sh"

echo -e "${los}"
echo -E "$_s_title"
echo -e "${los}"

_ds=$(date +"%Y-%m-%d")
_ts=$(date +"%T")
setupLogFile="/tmp/yamon/setup ($_ds $_ts).log"
[ ! -d "/tmp/yamon" ] && mkdir -p "/tmp/yamon"
[ ! -f "$setupLogFile" ] && touch "$setupLogFile"

echo -e "${_nl}This script will guide you through the process of setting up the${_nl}basic parameters in your \`config.file\` for YAMon$_version.${_nl}${_nl}See https://usage-monitoring.com/download.php for more detailed instructions${_nl}regarding the setup process.${_nl}NB - a number of the advanced (aka less commonly used) settings${_nlsp}are not currently addressed in this script.${_nl}${_nlsp}If you want to use any of those features, you can edit your${_nlsp}\`config.file\` directly.${_nl}${los}${_nl}"
echo -e "A log file will be created showing of the selections you make in the${_nl}upcoming prompts.  The name of the log file is:${_nlsp}\`$setupLogFile\`${_nl}If you encounter any issues during the setup process, please send ${_nl}your log, screen shots and as much additional info as ${_nl}possible to install@usage-monitoring.com.${_nl}"
echo -e "
NB - If you are updating from a previous version of YAMon, back up 
everything *before* proceeding!  This includes any customizations 
you've made to devices in the reports - see 
https://usage-monitoring.com/help/?t=export-users

For more help with the installation process, see
    https://usage-monitoring.com/help/?c=Install
"
sleep $delay
[ -n "$_canClear" ] && clear

echo -e "${los}${_nl}One last thing before starting, in the upcoming prompts,  
the recommended (or default) values will be highlighted with an asterisk (*).
To accept the default, simply hit <return>; otherwise, enter your preferred value
and then hit <return>.
${los}"

if [ -f "${d_baseDir}/config.file" ] ; then
	echo -e "\n\n*** Backing up existing config file '${d_baseDir}/config.file'\n    to '${d_baseDir}/config.old' (just to be safe)"
	SetupLog "Config file: ${d_baseDir}/config.file' backed up to ${d_baseDir}/config.old"
	cp "${d_baseDir}/config.file" "${d_baseDir}/config.old"
else
	oldInstall=$(find $(dirname "$d_baseDir") -name 'config.file'  | grep -n '')
	if [ -n "$(echo "$oldInstall")" ] ; then
		Prompt 't_cp' "You already have at least one existing YAMon installation.\n    Would you like to copy the settings from your current 'config.file'\n    to '${d_baseDir}'?" "$yn_y" '1' $zo_r
		if [ "$t_cp" -eq 1 ] && [ "$(echo "$oldInstall" | wc -l)" -eq "1" ] ; then
			CopySettings $oldInstall
		elif [ "$t_cp" -eq 1 ] ; then
			nn='123456789'
			options=${nn::$(echo "$oldInstall" | wc -l)}
			Prompt 't_whichInstall' "Which config.file would you like to use?\n$(IndentListS "$oldInstall")" "Pick one of the options: [$options]" '1' "^[$options]$"
			CopySettings "$(echo "$oldInstall" | grep "^$t_whichInstall:")"
		fi
	fi
fi

if [ ! -f "${d_baseDir}/config.file" ]; then
	echo -e "\n\n*** Using default configuration settings from  '${d_baseDir}/default_config.file'"
	cp "${d_baseDir}/default_config.file" "${d_baseDir}/config.file"
fi

_configFile="${d_baseDir}/config.file"

[ ! -f "${d_baseDir}/includes/paths.sh" ] && $(${d_baseDir}/setPaths.sh)

showEcho=1 # to prevent redirection of all output to the logs
source "${d_baseDir}/includes/shared.sh"

configStr=$(cat "$_configFile")

[ -n "$_canClear" ] && clear

SetupLog "Launched setup.sh - v$_version" 2
SetupLog "Baseline settings: \`$_configFile\`" 2

dd_str='DD-WRT'
op_str='OpenWrt'
le_str='LEDE'
tu_str='Turris'
am_str='ASUSWRT-Merlin'

_firmware=0
[ -n "$(which nvram)" ] && _has_nvram=1
[ -n "$(which uci)" ] && _has_uci=1

if [ -f "/etc/openwrt_release" ] ; then
	distro=$(cat /etc/openwrt_release | grep -i 'DISTRIB_ID' | cut -d"'" -f2)
	installedfirmware=$(cat /etc/openwrt_release | grep -i 'DISTRIB_DESCRIPTION' | cut -d"'" -f2)
	installedversion=''
	installedtype=''
	if [ "$distro" == "$le_str" ] ; then
		le_str='LEDE (*)'
		_firmware=4
	else
		tu_str='Turris (*)'
		_firmware=6
	
	fi
elif [ "$_has_nvram" == "1" ] ; then
	installedfirmware=$(uname -o)
	if [ "$installedfirmware" == "$dd_str" ] ; then
		_firmware=0
		dd_str='DD-WRT (*)'
	elif [ "$installedfirmware" == "$op_str" ] ; then
		op_str='OpenWrt (*)'
		_firmware=1
	elif [ "$installedfirmware" == "$am_str" ] ; then
		am_str='ASUSWRT-Merlin (*)'
		_firmware=2
	elif [ "$installedfirmware" == "Tomato" ] ; then
		_firmware=3	
	fi
	if [ $_firmware == 2 ] ; then
		routermodel=$(nvram get model)
		[ -z "$routermodel" ] && routermodel=$(nvram get modelNumber)
		installedversion=$(nvram get buildno)_$(nvram get extendno)
		installedtype='merlin'
 	elif [ $_firmware == 3 ] ; then
 		routermodel=$(nvram get t_model_name)
		installedversion=$(nvram get os_version | cut -d' ' -f1,2)
 		installedtype='Tomato'
	else
		routermodel=$(nvram get DD_BOARD)
		installedversion=$(nvram get os_version)
		installedtype=$(nvram get dist_type)
	fi
fi

if [ -d /tmp/sysinfo/ ] ; then
	model=$(cat /tmp/sysinfo/model)
	board=$(cat /tmp/sysinfo/board_name)
	routermodel="$model $board"
fi

SetupLog "Router Model: $routermodel" 2
SetupLog "Installed firmware: $installedfirmware $installedversion $installedtype" 2

installed=$(cat "$_configFile" | grep '_installed' | cut -d"'" -f2)
[ -z "$installed" ] && UpdateConfig '_installed' "$(date +"%Y-%m-%d %H:%M:%S")"
UpdateConfig '_updated' "$(date +"%Y-%m-%d %H:%M:%S")"
UpdateConfig '_router' "$routermodel"
UpdateConfig '_firmwareName' "$installedfirmware $installedversion $installedtype"

t_installmode='b'
Prompt 't_installmode' "Do you want run setup in Basic(*) or Advanced mode?" "Options:
      \`b\` -> Basic mode: fewer prompts; most default settings will be selected automatically (*)
      \`a\` -> Advanced mode: more prompts to better tailor your settings" "$t_installmode" "^[aAbB]$" 'running-setup'
	
SetupLog "Install mode: $t_installmode" 2

echo -e "${_nl}${_nl}NB - You can always fine-tune your settings later on by manually editing${_nlsp}\`config.file\` (in \`${d_baseDir}/config.file\`)."

Prompt '_firmware' 'Which firmware variant is running on your router?' "Options:
      \`0\` -> $dd_str
      \`1\` -> $op_str
      \`2\` -> $am_str
      \`3\` -> Tomato
      \`4\` -> $le_str
      \`5\` -> Xwrt-Vortex
      \`6\` -> $tu_str
      \`7\` -> Padavan" $_firmware ^[0-7]$

if [ "$_firmware" == "0" ] ; then
	lan_proto=$(nvram get lan_proto)
	SetupLog "lan_proto --> $lan_proto" 2
	[ ! "$lan_proto" == "dhcp" ] && echo -e "
	$wrn
	$bl_a
	  ##   It appears that your router is not the DHCP Server for
	  ##   your network.
	  ##   YAMon gets its data via \`iptables\` calls.  They only
	  ##   return meaningful data from the DHCP Server.
	$bl_a
	  ##   You must enable this feature on this router if you want to use YAMon!
	$bl_a
	  ##   DD-WRT web GUI: \`Setup\`-->\`Basic Setup\` -->\`Network Address Server Settings (DHCP)\`
	$bl_a
	$loh" && sleep $delay
	sfe_enable=$(nvram get sfe)
	SetupLog "sfe_enable --> $sfe_enable" 2
	[ "$sfe_enable" == "1" ] && echo -e "
	$wrn
	$bl_a
	  ##   The \`Shortcut Forwarding Engine\` is enabled in your DD-WRT config.
	  ##   SFE alters the normal flow of packets through \`iptables\` and that
	  ##   prevents YAMon from accurately reporting the traffic on
	  ##   your router.
	$bl_a
	  ##   YAMon will not report properly if you do not disable this feature!
	$bl_a
	  ##   DD-WRT web GUI: \`Setup\`-->\`Basic Setup\` -->\`Optional Settings\`
	$bl_a
	$loh" && sleep 5

	upnp_enable=$(nvram get upnp_enable)
	SetupLog "upnp_enable --> $upnp_enable" 2
	[ "$upnp_enable" == "1" ] && echo -e "
	$wrn
	$bl_a
	  ##   \`UPnP\` is enabled in your DD-WRT config.
	  ##   UPnP alters the normal flow of packets through \`iptables\` and that
	  ##   will likely prevent YAMon from accurately reporting the traffic on
	  ##   your router.
	$bl_a
	  ##   It is recommended that you disable this feature!
	$bl_a
	  ##   DD-WRT web GUI: \`NAT / QoS\`-->\`UPnP\` -->\`UPnP Configuration\`
	$bl_a
	$loh" && sleep 5

	privoxy_enable=$(nvram get privoxy_enable)
	SetupLog "privoxy_enable --> $privoxy_enable" 2
	[ "$privoxy_enable" == "1" ] && echo -e "
	$wrn
	$bl_a
	  ##   \`Privoxy\` is enabled in your DD-WRT config.
	  ##   Privoxy alters the normal flow of packets through \`iptables\` and
	  ##   that *will* prevent YAMon from accurately reporting the traffic
	  ##   on your router.
	$bl_a
	  ##   YAMon will not report properly if you do not disable this feature!
	$bl_a
	  ##   DD-WRT web GUI: \`Services\`-->\`Adblocking\`-->\`Privoxy\`
	$bl_a
	$loh" && sleep 5

	ntp_enable=$(nvram get ntp_enable)
	SetupLog "ntp_enable --> $ntp_enable" 2
	[ ! "$ntp_enable" == "1" ] && echo -e "
	$wrn
	$bl_a
	  ##   \`NTP Client\` is *not* enabled in your DD-WRT config.
	  ##   The NTP Client allows you to set your time zone and synchronize
	  ##   the clock on your router.
	$bl_a
	  ##   YAMon will likely not provide accurate reports if you do not
	  ##   enabled this feature!
	$bl_a
	  ##   DD-WRT web GUI: \`Setup\`-->\`Basic Setup\`-->\`Time Settings\`
	$bl_a
	$loh" && sleep 5

	schedule_enable=$(nvram get schedule_enable)
	schedule_hours=$(nvram get schedule_hours)
	schedule_minutes=$(nvram get schedule_minutes)
	schedule_reboot=0
	SetupLog "schedule_enable --> $schedule_enable ($schedule_hours:$schedule_minutes)" 2
	[ "$schedule_enable" == "1" ] && [ "$schedule_hours" == "0" ] && [ "$schedule_minutes" -lt "10" ] && echo -e "
	$wrn
	$bl_a
	  ##   Your router is scheduled to auto-reboot at '$schedule_hours:$schedule_minutes'.
	  ##   This may interfere with the YAMon function that consolidates
	  ##   the daily totals into the monthly usage file.
	$bl_a
	  ##   If you must auto-reboot your router, please do so after ~12:15AM!
	$bl_a
	  ##   DD-WRT web GUI: \`Administration\`-->\`Keep Alive\`-->\`Schedule Reboot\`
	$bl_a
	$loh" && schedule_reboot=1 && sleep 5
	flags="{lan_proto:$lan_proto, sfe_enable:$sfe_enable upnp_enable:$upnp_enable, privoxy_enable:$privoxy_enable, ntp_enable:$ntp_enable, schedule_reboot:$schedule_reboot}"
	SetupLog "Install flags --> $flags" 2
	#to-do - add flags to config.file
fi
[ "$t_installmode" == 'b' ] && CheckDataPath
Prompt '_ispBillingDay' 'What is your ISP bill roll-over date? 
    (i.e., on what day of the month does your usage reset to zero)' 'Enter the day number [1-31]:' '1' "^([1-9]|[12][0-9]|[3][01])$"
Prompt '_monthlyDataCap' 'Does your plan with your ISP have a data usage cap?' "Options:
      \`0\` -> No, I have an unlimited data plan (*)
	  \`##\` -> Otherwise, enter your data cap in GB [1-9999]" '0' "^[0-9]{1,4}$"
Prompt '_unlimited_usage' 'Does your ISP offer `Bonus Data`?
    (i.e., uncapped data usage during offpeak hours)' "$yn_n" '0' $zo_r
if [ "$_unlimited_usage" == "1" ] ; then
	Prompt '_unlimited_start' 'Start time for bonus data?' 'Enter the time in [hh:mm] 24hr format' '' "^(00|[1-9]|1[0-9]|2[0-3]):[0-5][0-9]$" '_unlimited_usage'
	Prompt '_unlimited_end' 'End time?' 'Enter the time in [hh:mm] 24hr format' '' "^(00|[1-9]|1[0-9]|2[0-3]):[0-5][0-9]$" '_unlimited_usage'
fi

if [ "$t_installmode" == 'b' ] ; then
	_purgeOldFiles=1
else
	Prompt '_purgeOldFiles' 'Do you want to purge old logs and backups at the end of your billing interval?
If yes, files more than 30 days old will be removed from your USB drive.
*** NB - This will *NOT* remove data files!' "$yn_y" '1' $zo_r '_purgeOldFiles'
fi

[ -n "$_canClear" ] && clear

if [ -z "$_dbkey" ] ; then
	echo -e "${los}${_nl}An important pause in the the setup process...

Before getting to the next prompt, please read the following carefully!

A number of settings and customizations in the YAMon reports are, by default, retained
from one session to the next in a \`LocalStorage\` variable.  By design, a LocalStorage
variable is available only to the device (and browser) where it was created.  In the 
context of the YAMon reports, this means that customized names and groupings for the
devices on your network which you create on your PC will not automatically appear when 
you view the reports on your tablet... worse yet, you'll have to manually transfer 
or recreate them!   
The short reason for this is that for security reasons, the web server on your router  
does not provide support for 'cgi/bin' so I cannot save your changes back to the router.
The next best option is the LocalStorage variable but with the limitations as stated above.  
See http://usage-monitoring.com/help/?t=settings for a more detailed explanation...

As an alternative to the manual synchronization, there's a database intregation feature.  
When this *optional* setting is enabled, your settings and customizations will be saved 
to a database at usage-monitoring.com and any devices that you use to view the reports 
will see things exactly the same way.

If you want to use the new access restriction feature, you must enable the database integration.

Some users have expressed concerns that this means that your settings will get save to 
'my' database.  I sympathize entirely with this!  To help address those concerns, I save the
settings into separate database tables that have randomly generated names; so, in short, I do 
not know who belongs to what settings. Further, the most sensitive info in the settings,
as far as I know, would be the the MAC addresses (of just those devices associated 
with customized names). 
See also https://usage-monitoring.com/privacy.php

"
	Prompt 't_dbkey' 'Do you want to enable the database integration feature?
    If you do not trust my emphatic assertions that I 
      1. provide this option as a convenience only, and
      2. have no interest whatsoever in your settings,
    then do *NOT* enable this option.
    OTOH, if you want to use the access restrictions feature, 
    you must enable this option... Your call!' "$yn_n" '0' $zo_r
	if [ "$t_dbkey" -eq "1" ] ; then
		wget http://usage-monitoring.com/db/createdb.php -U "YAMon-Setup" -qO /tmp/yamon/dbkey.txt
		UpdateConfig "_dbkey" "$(cat /tmp/yamon/dbkey.txt)"
		rm /tmp/yamon/dbkey.txt
	fi
fi

if [ "$t_installmode" == 'b' ] ; then
	
	if [ "$_firmware" == "1" ] || [ "$_firmware" == "4" ] || [ "$_firmware" == "6" ] || [ "$_firmware" == "7" ] ; then
		lan_ip=$(uci get network.lan.ipaddr)
		[ -z "$lan_ip" ] && lan_ip=$(ifconfig br-lan | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
	else
		lan_ip=$(nvram get lan_ipaddr)
	fi
	
else

	Prompt '_updateTraffic' 'How frequently would you like to check the traffic data?' 'Enter the interval in minutes [1-30 min]' '4' "^([1-9]|[12][0-9]|30)$"
	t_wid=1
	Prompt 't_wid' "Do you want to store your data in the default directory?
      - i.e., \`$d_baseDir/data\`" "$yn_y" $t_wid $zo_r
	[ "$t_wid" == "0" ] && Prompt '_dataDir' "Enter the path to your data directory" "Options:${_nls}* a relative path within the install folder - e.g., data/ (*)${_nls}* an absolute path elsewhere on your network - e.g,  /<path>/" "data/" $re_path_slash

	CheckDataPath
	
	if [ "$_firmware" == "1" ] || [ "$_firmware" == "4" ] || [ "$_firmware" == "6" ] || [ "$_firmware" == "7" ] ; then
		d_wwwPath='/tmp/www/'
		lan_ip=$(uci get network.lan.ipaddr)
		[ -z "$lan_ip" ] && lan_ip=$(ifconfig br-lan | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
		[ "$_wwwURL" == '/user' ] && _wwwURL='/yamon'
	elif [ "$_firmware" == "2" ] || [ "$_firmware" == "3" ] || [ "$_firmware" == "5" ] ; then
		d_wwwPath='/tmp/var/wwwext/'
	else
		lan_ip=$(nvram get lan_ipaddr)
	fi

	Prompt '_wwwPath' 'Specify the path to the web directories?' "The path must start and end with a \`/\`" "$d_wwwPath" $re_path_slash
	Prompt '_wwwURL' "Specify the URL path to the reports - e.g. $lan_ip\`<path>\`?" "  \`<path>\` must start and end with a \`/\`.  
      NB - enter just the path & do *NOT* include the IP address!" "$d_wwwURL" $re_path_slash

	Prompt '_includeBridge' "Do you have a bridge on your network?${_nlsp}(i.e., a second router or other device to extend the wireless range)" "$yn_n" '0' $zo_r
	if [ "$_includeBridge" == "1" ] ; then
		Prompt '_bridgeMAC' "What is the MAC address for your bridge device?${_nlsp}See the help topic if you have multiple bridging devices" "Enter a valid MAC address - e.g., 11:22:33:44:55:66" '' "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$" '_includeBridge'
	fi

	Prompt '_logDir' 'Where do you want to create the logs directory?' "Options:${_nlsp}* a relative path within the install folder - e.g., logs/ (*)${_nlsp}* an absolute path elsewhere on your network - e.g,  /<path>/" "logs/" $re_path_slash  '_enableLogging'
	Prompt '_loglevel' 'How much detail do you want in the logs?' "Options:${_nlsp}\`0\` -> really verbose${_nlsp}\`1\` -> most logging messages (*)${_nlsp}\`2\` -> fewer messages${_nlsp}\`3\` -> serious messages only${_nlsp}\`99\` -> effectively no logging" '1' "^([0123]|99)$" '_enableLogging'

	Prompt '_doLiveUpdates' 'Do you want to report `live` usage?' "$yn_y" '1' $zo_r
	[ "$_doLiveUpdates" == "1" ] && Prompt '_doArchiveLiveUpdates' "Do you want to archive the \`live\` usage data?${_nlsp}NB - If yes, note that these files could consume a *lot* of disk space!" "$yn_n" '0' $zo_r '_doLiveUpdates'

	Prompt '_doDailyBU' 'Enable daily backup of data files?  If yes, they will be compressed' "$yn_y" '1' $zo_r

	ftpput=$(which ftpput)
	if [ -z "$ftpput" ] ; then
		SetupLog "ftpput --> ftpput is not included" 2
		UpdateConfig "_enable_ftp" "0"
	else
		SetupLog "ftpput --> $ftpput" 2
		Prompt '_enable_ftp' "Do you want to mirror a copy of your data files to an external FTP site?${_nlsp}NB - *YOU* must setup the FTP site yourself!" "$yn_n" '0' $zo_r
		if [ "$_enable_ftp" == "1" ] ; then
			Prompt '_ftp_site' 'What is the URL for your FTP site?' 'Enter just the URL or IP address' '' '' '_enable_ftp'
			Prompt '_ftp_user' 'What is the username for your FTP site?' '' '' '' '_enable_ftp'
			Prompt '_ftp_pswd' 'What is the password for your FTP site?' '' '' '' '_enable_ftp'
			Prompt '_ftp_dir' 'What is the path to your FTP storage directory?' "Options: ''->root level -or- enter path" '' '' '_enable_ftp'
			echo -e "${los}${_nls}You will have to manually create the year/month${_nls}sub-directories on your FTP site for the data files.${los}${_nl}"
		fi
	fi
fi

_configFile="${d_baseDir}/config.file"
if [ ! -f "$_configFile" ] ; then
	touch "$_configFile"
	SetupLog "Created and saved settings in new file: \`$_configFile\`" 2
	echo -e "${los}${_nls}Created and saved settings in new file: \`$_configFile\`${los}"
else
	cp "$_configFile" "${d_baseDir}/config.old"
	SetupLog "Updated existing settings: \`$_configFile\`" 2
    echo -e "${los}${_nls}Saved configuration settings to \`$_configFile\`${_nls}& copied previous file to \`${d_baseDir}/config.old\`${los}"
fi

echo -e "$configStr" > "$_configFile"

su="${d_baseDir}/start.sh 'reboot'"
sd="${d_baseDir}/pause.sh"

t_perm="+x"

SetupLog "Changed \`$d_baseDir\` permissions to: \`$t_perm\`" 2
chmod "$t_perm" -R "$d_baseDir"
chmod "$t_perm" -R "$_wwwPath"
SetupLog "Changed \`$_wwwPath\` permissions to: \`$t_perm\`" 2
chmod "$t_perm" -R "${d_baseDir}/www"
SetupLog "Changed \`${d_baseDir}/www\` permissions to: \`$t_perm\`" 2

startup_delay='10'
if [ "$_firmware" == "1" ] || [ "$_firmware" == "4" ] ; then
	etc_init="/etc/init.d/yamon4"
	if [ -f "$etc_init" ] && [ -n "$(cat "$etc_init" | grep -e "$su" )" ] ; then
		SetupLog "Startup - $su already exists in \`$etc_init\`" 2
	elif [ ! -f "$etc_init" ] || [ -z "$(cat "$etc_init" | grep -e "$su" )" ] ; then
		[ "$t_installmode" == 'a' ] && Prompt 'startup_delay' "By default, \`start.sh\` will delay for 10 seconds prior to starting.${_nlsp}Some older/slower routers may require extra time." 'Enter the start-up delay [0-300]' '10' "^([0-9]|[1-9][0-9]|[1-2][0-9][0-9]|300)$"

		SetupLog "Created YAMon init script in \`/etc/init.d/\`" 2
		[ ! -d "/etc/init.d/" ] && mkdir -p "/etc/init.d/" # is this even necessary?
		echo "#!/bin/sh /etc/rc.common
START=99
STOP=10
start() {
	# commands to launch application
	sleep $startup_delay
	$su &
}
stop() {
	$sd
	return 0
}
restart() {
	$su
	return 0
}
boot() {
	start
}" > "$etc_init"
		chmod +x "$etc_init"
	else
		SetupLog "Did not create start/stop entries in $etc_init?!?" 2
	fi
elif [ "$_firmware" == "2" ] || [ "$_firmware" == "3" ] || [ "$_firmware" -eq "5" ]; then # Tomato, AsusMerlin & variants 

	cnsu=$(nvram get script_usbmount)
	if [ -n "$cnsu" ] && [ -n "$(echo $cnsu | grep "$su")" ] ; then
		SetupLog "Startup - $su already exists in \`nvram-->script_usbmount\`" 2
	elif [ -z "$cnsu" ] && [ -z "$(echo $cnsu | grep "$su")" ] ; then
		[ "$t_installmode" == 'a' ] && Prompt 'startup_delay' "By default, \`start.sh\` will delay for 60 seconds prior to starting.${_nlsp}Some older/slower routers may require extra time." 'Enter the start-up delay [0-300]' '60' "^([0-9]|[1-9][0-9]|[1-2][0-9][0-9]|300)$"
		SetupLog "Added $su to nvram-->script_usbmount" 2
		nvram set script_usbmount="$cnsu
sleep $startup_delay
$su"

	else
		SetupLog "Did not create start entries in nvram?!?" 2
	fi

	cnsd=$(nvram get script_usbumount)
	if [ -n "$cnsd" ] && [ -n "$(echo $cnsd | grep "$sd")" ] ; then
		SetupLog "Shutdown - $sd already exists in \`nvram-->script_usbumount\`" 2
	elif [ -z "$cnsd" ] && [ -z "$(echo $cnsd | grep "$sd")" ] ; then
		SetupLog "Added $sd to nvram-->script_usbumount" 2
		nvram set script_usbumount="$cnsd
$sd"
 	else
		SetupLog "Did not create stop entries in nvram?!?" 2
 	fi
	nvram commit
	
elif [ "$_firmware" == "6" ] || [ "$_firmware" == "7" ] ; then

	etc_rc="/etc/rc.local"
	if [ -f "$etc_rc" ] && [ -n "$(cat "$etc_rc" | grep -e "$su" )" ] ; then
		SetupLog "Startup - $su already exists in \`$etc_rc\`" 2
	elif [ ! -f "$etc_rc" ] || [ -z "$(cat "$etc_rc" | grep -e "$su" )" ] ; then
		[ "$t_installmode" == 'a' ] && Prompt 'startup_delay' "By default, \`start.sh\` will delay for 10 seconds prior to starting.${_nlsp}Some older/slower routers may require extra time." 'Enter the start-up delay [0-300]' '10' "^([0-9]|[1-9][0-9]|[1-2][0-9][0-9]|300)$"
		SetupLog "Added $su into startup script in $etc_rc" 2		
		sed -i "s~exit 0~sleep $startup_delay\n${su} \nexit 0~g" "$etc_rc"
	else
		SetupLog "Did not create start/stop entries in $etc_rc?!?" 2
	fi

else

	cnsu=$(nvram get rc_startup)
	
	if [ -n "$cnsu" ] && [ -n "$(echo $cnsu | grep "$su")" ] ; then
		SetupLog "Startup - $su already exists in \`nvram-->rc_startup\`" 2
	elif [ -z "$cnsu" ] && [ -z "$(echo $cnsu | grep "$su")" ] ; then
		[ "$t_installmode" == 'a' ] && Prompt 'startup_delay' "By default, \`start.sh\` will delay for 10 seconds prior to starting.${_nlsp}Some older/slower routers may require extra time." 'Enter the start-up delay [0-300]' '10' "^([0-9]|[1-9][0-9]|[1-2][0-9][0-9]|300)$"
		SetupLog "Added $su to nvram-->rc_startup" 2
		nvram set rc_startup="$cnsu
sleep $startup_delay
$su"
		nvram commit

	else
		SetupLog "Did not create start/stop entries in nvram?!?" 2
	fi
fi

turris_webapp="/usr/share/turris-webapps/10_yamon.conf"
if [ "$_firmware" == "6" ] ; then

	if [ -f "$turris_webapp" ] ; then
		SetupLog "Turris web app file already exists: $turris_webapp" 2
	else
		Prompt 't_webapp' 'Do you want to create a web-app entry YAMon?' "$yn_y" '1' $zo_r
		if [ "$t_webapp" == "1" ] ; then
			touch "$turris_webapp"
			echo -e "URL=\"/yamon\"
	NAME=\"YAMon - Usage Monitoring by Device\"
	ICON=\"yamon-logo.png\"" > $turris_webapp

			src="https://usagemonitoringcom.ipage.com/current/images/yamon-logo.png"
			dst="/www/webapps-icons/yamon-logo.png"
			wget "$src" -qO "$dst"
			SetupLog "Created Turris web app file: $turris_webapp" 2
		else
			SetupLog "Declined to create Turris web app file " 2
		fi
	fi
fi

echo -e "${_nl}${los}${_nl}Setup is (finally) complete!!!

One last thing to do before restarting the new version... 
Prior versions of YAMon v4 may have introduced some errors in various
files."

Prompt 't_fix' 'Do you run the fixes script now?  It might take a couple minutes to complete...' "$yn_y" '1' $zo_r
if [ "$t_fix" == "1" ] ; then
	echo -e "Thanks in advance for your patience!"
	source "${d_baseDir}/includes/fixes.sh"
fi

Prompt 't_launch' 'Do you want to launch YAMon now?' "$yn_y" '1' $zo_r
if [ "$t_launch" == "1" ] ; then
	SetupLog "Launched " 2
	echo -e "${_nl}${los}${_nl}[Re]starting YAMon$_version${_nl}"
	${d_baseDir}/start.sh
	exit 0
fi

echo -e "${_nl}${los}${_nl}YAMon$_version is now configured and ready to run.${_nl}To launch YAMon manually, enter \`${d_baseDir}/start.sh\`.${_nl}${_nl}If you have questions, please send them to questions@usage-monitoring.com${_nl}(Include log files and/or screenshots if you have installation difficulties)${_nl}${_nl}Thank you for installing YAMon.  You can show your appreciation and${_nl}support future development by donating at https://www.paypal.me/YAMon/.${_nl}${_nl}Thx!${_nl}${_nlsp}Al${_nl}"
