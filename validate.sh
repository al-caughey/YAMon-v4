#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# Script to help validate the installation of YAMon4.x
#
# History
# 2020-01-26: 4.0.7 - added; added more checks
#
##########################################################################
LS_Path(){
	local tp=$1
	echo -e "\nls -la ${tp}" >> $vl
	ls -la ${tp} | grep -v "\.$" >> $vl
}

tmplog='/tmp/yamon/'
d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/config.file"
source "${d_baseDir}/includes/paths.sh"

vl="${tmplog}validation.log"
[ -f "$vl" ] && rm "$vl"
touch "$vl"

echo 'Validation Log' > $vl

echo -e "_router: ${_router}" >> $vl
echo -e "_firmware: ${_firmware}" >> $vl
echo -e "_firmwareName: ${_firmwareName}" >> $vl
echo -e "_dbkey: ${_dbkey}" >> $vl

LS_Path "/www"
LS_Path "${_wwwPath}"
LS_Path "${_wwwPath}js/"
LS_Path "${tmplog}"
LS_Path "${_path2logs}"
LS_Path "${_path2data}"
LS_Path "${_path2CurrentMonth}"

echo -e "\ncat ${_usersFile}" >> $vl
cat ${_usersFile} >> $vl
[ -n "$(cat ${_usersFile} | grep ">> $d_baseDir")" ] && echo -e "\n*** Error in ${_usersFile}" >> $vl

echo -e "\nScheduled jobs" >> $vl
if [ "$_firmware" -eq "0" ] ; then #DD-WRT
	echo -e "\ncat /tmp/cron.d/yamon_jobs" >> $vl
	cat /tmp/cron.d/yamon_jobs  >> $vl
elif [ "$_firmware" -eq "1" ] || [ "$_firmware" -eq "4" ] || [ "$_firmware" -eq "6" ] || [ "$_firmware" -eq "7" ] ; then #OpenWRT & variants
	echo -e "\ncrontab -l" >> $vl
	crontab -l  >> $vl
elif [ "$_firmware" -eq "2" ] || [ "$_firmware" -eq "5" ] ; then #AsusMerlin & variants
	echo -e "\ncat /tmp/cron.d/yamon_jobs" >> $vl
	cat /tmp/cron.d/yamon_jobs  >> $vl
elif [ "$_firmware" -eq "3" ]; then #Tomato
	echo -e "\ncru l" >> $vl
	cru l
fi

echo -e "\niptables entries" >> $vl
echo -e "* FORWARD:" >> $vl
iptables -L FORWARD | grep 'YAMONv40' >> $vl
echo -e "\nINPUT:" >> $vl
iptables -L INPUT | grep 'YAMONv40' >> $vl
echo -e "\n* OUTPUT:" >> $vl
iptables -L OUTPUT | grep 'YAMONv40' >> $vl
echo -e "\n* All Others:" >> $vl
iptables -L | grep 'Chain YAMONv40' >> $vl

echo -e "\n* YAMONv40:" >> $vl
iptables -L YAMONv40 >> $vl


cat "$vl"