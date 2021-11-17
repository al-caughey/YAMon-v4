##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# Script to download the latest files from usage-monitoring.com
#
#   2019-10-26 - updated for v4.0.5... added new files to the list
#   2019-10-26 - updated for v4.0
#   2019-08-02 - added checkusers.sh
#
##########################################################################
_ts=$(date +"%s")
getlatest()
{
	#echo "getlatest: $1 / $2 / $3" >&2
	local path=$1
	#spath="${path/.sh/.html}"
	local src="https://www.usage-monitoring.com/$directory/YAMon4/Setup/${path}?$_ts"
	local dst="${YAMON}${path}"
	local rm="$3"
	
	[ -z "$rm" ] && echo "  * $dst"
	if [ -z "$rm" ] && [ -x /usr/bin/curl ] ; then
		curl -sk --max-time 15 -o "$dst" --header "Pragma: no-cache" --header "Cache-Control: no-cache" -A "YAMon-Setup" "$src"
		rm='wget'
	else
		wget "$src" -U "YAMon-Setup" -qO "$dst"
		rm='wget'
	fi
	if [ ! -f "$dst" ] ; then
		[ "$err_num" -ge 3 ] && echo "
****************************
*** Could not install \`$dst\`
*** Exiting the install process.
***
*** See https://usage-monitoring.com/help/?t=download-failed
***
*** Send questions to install@usage-monitoring.com
****************************" && exit 0;
		err_num=$((err_num+1))
		echo -n "    --> download failed?!? Waiting 5 sec before trying again"
		n=1
		while [ 1 ]; do
			echo -n '.'
			[ "$n" -ge "5" ] && break
			n=$(($n+1))
			sleep 1
		done
		echo ''
		getlatest "$1" "$2" "$rm"
		return
	fi
	
	#change windows linefeeds to unix
	sed -i -e 's/\r$//' "$dst" #change windows linefeeds to unix

	if [ -f "$dst" ] && [ -n "$2" ] ; then
		echo "     > Loading source for $dst" >&2
		source "$dst"
	fi
	err_num=0
}
err_num=0

[ -z "$directory" ] && directory='current'
echo "
Downloading the latest version of:"
getlatest 'includes/version.sh' 1
getlatest 'default_config.file'

getlatest 'includes/dailytotals.sh'
getlatest 'includes/fixes.sh'
getlatest 'includes/prompts.sh' 1
getlatest 'includes/setupIPChains.sh'

showEcho=1 # to prevent redirection of all output to the logs
getlatest "includes/shared.sh"
getlatest 'includes/start-stop.sh'
getlatest 'includes/traffic.sh'

getlatest 'alias.sh'
getlatest 'block.sh'
getlatest 'calculate-daily-totals.sh'
getlatest 'changes.log'
getlatest 'check-network.sh'
getlatest 'clear-iptables.sh'
getlatest 'compare.sh'
getlatest 'copy-log.sh'
getlatest 'end-of-hour.sh'
getlatest 'end-of-day.sh'
getlatest 'getACRules.sh'
getlatest 'in-unlimited.sh'
getlatest 'new-billing-interval.sh'
getlatest 'new-day.sh'
getlatest 'new-hour.sh'
getlatest 'pause.sh'
getlatest 'purge.sh'
getlatest 'run-fixes.sh'
getlatest 'setPaths.sh'
getlatest 'start.sh'
getlatest 'update-live-data.sh'
getlatest 'update-reports.sh'
getlatest 'up-rev-users-js.sh'
getlatest 'validate.sh'
getlatest "setup$_version.sh"
[ -f "${YAMON}setup.sh" ] && rm "${YAMON}setup.sh"
ln -s "${YAMON}setup$_version.sh" "${YAMON}setup.sh"

[ ! -d "${YAMON}strings/${_lang:-en}" ] && mkdir -p "${YAMON}strings/${_lang:-en}"
getlatest "strings/title.inc" 1
getlatest "strings/${_lang:-en}/strings.sh" 1

[ ! -d "${YAMON}www" ] && mkdir -p "${YAMON}www"
[ ! -d "${YAMON}www/js" ] && mkdir -p "${YAMON}www/js"
[ ! -d "${YAMON}www/css" ] && mkdir -p "${YAMON}www/css"
[ ! -d "${YAMON}www/images" ] && mkdir -p "${YAMON}www/images"
getlatest "www/yamon${_version%\.*}.html"
getlatest "www/css/custom.css"

echo -e "\n*************************\nSet execute permissions..." >&2
chmod -R +x "${YAMON}"
