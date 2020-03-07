#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# Script to help validate the installation of YAMon4.x
#
# History
# 2020-01-26: 4.0.7 - added
#
##########################################################################

tmplog='/tmp/yamon/'
d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/config.file"
source "${d_baseDir}/includes/paths.sh"

vl="${tmplog}validation.log"
[ -f "$vl" ] && rm "$vl"
touch "$vl"

echo 'Validation Log' > $vl
echo -e "\nls -la /www" >> $vl
ls -la /www | grep -v "\.$" >> $vl

echo -e "\nls -la ${_wwwPath}" >> $vl
ls -la "$_wwwPath" | grep -v "\.$" >> $vl

echo -e "\nls -la ${_wwwPath}js/" >> $vl
ls -la "${_wwwPath}js/" | grep -v "\.$" >> $vl

echo -e "\nls -la ${tmplog}" >> $vl
ls -la "${tmplog}" | grep -v "\.$" >> $vl

echo -e "\nls -la ${_path2logs}" >> $vl
ls -la "${_path2logs}" | grep -v "\.$" >> $vl

echo -e "\nScheduled jobs" >> $vl
#if DD-WRT uncomment the next line
#cat /tmp/cron.d/yamon_jobs  >> $vl
#if OpenWrt & variants uncomment the next line
#crontab -l  >> $vl
#if Tomato uncomment the next line
#cru l

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