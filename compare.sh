#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# compares files on the router with those at https://usage-monitoring.com
# run: manually and by install
# History
# 2020-01-26: 4.0.7 - auto-change windows linefeeds to unix
# 2020-01-03: 4.0.6 - removed the sleep statements; updated formatting of output; strip latest history comment to improve matches
# 2019-12-23: 4.0.5 - no changes
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-11-06: added timestamp to wget call to compare.php to avoid cached pages?!?
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

[ -z "$directory" ] && directory='current'
d_baseDir="$YAMON"
[ -z "$d_baseDir" ] && d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/version.sh"

_ts=$(date +"%s")

getlatest()
{
	local path=$1
	#spath="${path/.sh/.html}"
	spath="${path}?$_ts"
	local src="http://www.usage-monitoring.com/$directory/YAMon4/Setup/${spath}"
	local dst="${YAMON}/${path}"

	if [ -x /usr/bin/curl ] ; then
		curl -sk --max-time 15 -o "$dst" --header "Pragma: no-cache" --header "Cache-Control: no-cache" -A "YAMon-Setup" "$src"
	else
		wget "$src" -U "YAMon-Setup" -qO "$dst"
	fi
	if [ -f "$dst" ] ; then
		echo "   --> downloaded to $dst"
		sed -i -e 's/\r$//' "$dst" #change windows linefeeds to unix
		local ext=$(echo -n "$dst" | tail -c 2)
		[ "$ext" == 'sh' ] && chmod 770 "$dst"
		
	else
		echo "   --> download failed?!?"
	fi
}

_sync=''
[ -f "/tmp/files-$directory.txt" ] && rm "/tmp/files-$directory.txt"

if [ "$param" == 'verify' ] ; then
	arg=''
	echo "

**********************************
Verifying that all files were downloaded successfully.

If the chart below shows files that are missing or differ
from the server, re-run install.sh.

If that still does not clear up the differences, see
	https://usage-monitoring.com/common-problems.php
"

else

    YAMON=$(cd "$(dirname "$0")" && pwd)
	[ -n "$1" ] && arg="&bv=$1"

	echo "
**********************************
This script allows you to compare the md5 signatures of the files on
your router with the current versions at https://usage-monitoring.com.

You can choose to compare or synchronize the files
(i.e., replace any differing or missing on your router with
those at usage-monitoring.com).
"

	resp=''
	echo "Compare \`current\` or \`dev\` directories?
NB - normally you should pick \`current\`"
	readstr="--> Enter \`d\` for \`dev\` or anything else for \`current\`: "
	read -p "$readstr" resp
	if [ "$resp" == 'd' ] || [ "$resp" == 'D' ] ; then
	directory='dev'
	fi
	echo "

***********************"
	resp=''
	echo "What would you like to do?"
	readstr="--> Enter \`s\` to sync the files or anything else to just compare: "
	read -p "$readstr" resp
	if [ "$resp" == 's' ] || [ "$resp" == 'S' ] ; then
	_sync=1
	fi
fi

echo "

***********************"
_ts=$(date +"%s")
wget "http://usage-monitoring.com/$directory/YAMon4/Setup/compare.php?$_ts$arg" -U "YAMon-Setup" -qO "/tmp/files-$directory.txt"

n=0
spacing='========================='
needsRestart=''
allMatch=''
echo "
Comparing files...
   remote path: \`https://usage-monitoring.com/$directory/YAMon4/Setup/\`
    local path: \`$YAMON\`

   file                              status
--------------------------------------------------"
while IFS=, read fn smd5
do
	path="$YAMON/$fn"
	n=$((n + 1))
	ts="$n. $fn:"
	pad=${spacing:0:$((32-${#ts}+1))}
	pad=${pad//=/ }

	#lmd5=$([ -f "$path" ] && echo $(md5sum "$path")| cut -d' ' -f1)
	lmd5w=$([ -f "$path" ] && cat "$path" | md5sum| awk '{print $1}')
	lmd5wo=$([ -f "$path" ] && cat "$path" | grep -v ": $_version -" | md5sum| awk '{print $1}')
	echo -n "$ts"
	echo -n "$pad"
	if [ "$smd5" == "-" ] ; then
		echo "?!? not on server"
		continue
	elif [ ! -f "$path" ] && [ ! "$smd5" == "-" ] ; then
		echo "+++  missing  +++"
	elif [ "$smd5" == "$lmd5w" ] ; then
		echo "    identical"
		continue
	elif  [ "$smd5" == "$lmd5wo" ] ; then
		echo "--> matches but missing $_version comment"
		continue
	else
		echo "***  differs  ***"
	fi
	allMatch=1
	[ "$_sync" == "1" ] && getlatest "$fn" && needsRestart=1
done < "/tmp/files-$directory.txt"
echo -n "--------------------------------------------------

Results:
* "
if [ "$needsRestart" == "1" ] ; then
	echo "One or more files were updated. Would you like to restart now?"
	readstr="--> Enter \`r\` to restart or anything else to exit: "
	read -p "$readstr" resp
	if [ "$resp" == 'r' ] || [ "$resp" == 'R' ] ; then
		${YAMON}/start.sh 0
	else
		echo "You will have to manually restart soon."
	fi
elif [ -z "$allMatch" ] ; then
	echo "All of your files are up-to-date."
elif [ -n "$allMatch" ] && [ "$param" == 'verify' ] ; then
	echo "One or more of your files did not download properly.
  Either re-run this script, or visit
  \`https://usage-monitoring.com/installv4.php\` to update the
  file(s) manually.

  NB - I recently learned that some firmware variants include a buggy version 
  of the wget function... If the compare results show that just certain files
  differ, you could have the affected firmware.  
  Use the manual install process instead at  \`https://usage-monitoring.com/installv4.php\`
  Sorry - the fix to wget is beyond my control!
  
  Send any questions or comments to install@usage-monitoring.com

  Exiting install.sh....

  "

  exit 0

elif [ -n "$allMatch" ] ; then
	echo "One or more of your files is out-of-date and should be updated.
  Either re-run this script and hit \`s\` to sync all files, or
  visit \`https://usage-monitoring.com/installv4.php\` to update selectively.
  
  NB - I recently learned that some firmware variants include a buggy version 
  of the wget function... If the compare results show that just certain files
  differ, you could have the affected firmware.  
  Use the manual install process instead at  \`https://usage-monitoring.com/installv4.php\`
  Sorry - the fix to wget is beyond my control!
"
fi

[ -z "$param" ] && echo "
Send any questions or comments to questions@usage-monitoring.com

Thanks!

Al

"
