#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
##########################################################################


IndentList(){
	echo -e "$1" | grep -Ev "^\s{0,}$" | sed -e "s~^\s\{0,\}~  * ~Ig" 
}

UpdateEntries(){
	local spacing='========================='	
	for line in $1; do
		local fn=$(echo "$line" | cut -d',' -f1)
		local pad=${spacing:0:$((32-${#fn}+1))}
		tlist=$(echo "$tlist" | sed -e "s~$fn~  $3 $fn${pad//=/ }$2~")
	done
}

[ -z "$directory" ] && directory='current'
d_baseDir="$YAMON"
[ -z "$d_baseDir" ] && d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/version.sh"

YAMON=$(cd "$(dirname "$0")" && pwd)
[ -n "$1" ] && arg="?bv=$1&sc=1" || arg="?sc=1"

echo "
**********************************
This script compares the md5 signatures of the dev & current files-$directory
at http://usage-monitoring.com.
"
directory='dev'
wget "http://usage-monitoring.com/$directory/YAMon4/Setup/compare.php$arg" -U "YAMon-Setup" -qO "/tmp/files-$directory.txt"
directory='current'
wget "http://usage-monitoring.com/$directory/YAMon4/Setup/compare.php$arg" -U "YAMon-Setup" -qO "/tmp/files-$directory.txt"

n=0
spacing='========================='
allMatch=''
echo "
Comparing files...
    dev path: \`http://usage-monitoring.com/dev/YAMon4/Setup/\`
    current path: \`http://usage-monitoring.com/current/YAMon4/Setup/\`
	
	
   file                              status
--------------------------------------------------"

devlist=$(cat /tmp/files-dev.txt | cut -d, -f1)
curlist=$(cat /tmp/files-current.txt | cut -d, -f1)

tlist=$(echo -e "$devlist\n$curlist" | sort -u)

dfl=$(echo $devlist | tr -s ' ' '|')
diffcurrent=$(echo "$curlist" | egrep -v "$dfl" | cut -d',' -f1)
UpdateEntries "$diffcurrent" "on \`current\` but not \`dev\`" '-'

cfl=$(echo $curlist | tr -s ' ' '|')
diffdev=$(echo "$devlist" | egrep -v "$cfl" | cut -d',' -f1)
UpdateEntries "$diffdev" "on \`dev\` but not \`current\`" '+'

dl=$(echo $(cat '/tmp/files-dev.txt' | sed -e "s~\n~|~") | tr -s ' ' '|')
unchanged=$(cat '/tmp/files-current.txt' | egrep "$dl" | cut -d',' -f1)
UpdateEntries "$unchanged" "same" '='

dl=$(echo $(cat '/tmp/files-dev.txt' | sed -e "s~\n~|~") | tr -s ' ' '|')
changed=$(cat '/tmp/files-current.txt' | egrep -v "$diffcurrent|$diffdev|$dl")
UpdateEntries "$changed" "changed!" '*'

echo -e "$tlist"
