#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# tidies up things just after the end of each hour
# run: by cron
# History
# 2020-01-26: 4.0.7 - changed to list Tomato cru jobs in the log (thx tvlz)
# 2020-01-03: 4.0.6 - get acRules based upon firmware
# 2019-12-23: 4.0.5 - added log messages; added JS to head of tmplogFile
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

d_baseDir=$(cd "$(dirname "$0")" && pwd)
source "${d_baseDir}/includes/shared.sh"
source "${d_baseDir}/includes/traffic.sh"

hr=$(echo $_ts | cut -d':' -f1)
sleep 59
Send2Log "End of hour: $hr" 1

GetTraffic '-vnxZ'  # get the data and zero the tables

sleep 10 # delay ~10 seconds into next hour to allow tasks from previous hour to finish... might have to adjust this value

Send2Log "End of hour: append \`$rawtraffic_hr\` to \`$rawtraffic_day\`"
cat "$rawtraffic_hr" >> "$rawtraffic_day"

if [ "$_firmware" -eq "0" ] ; then
	acRules="$(cat /tmp/cron.d/yamon_jobs)"
elif [ "$_firmware" -eq "3" ] || [ "$_firmware" -eq "2" ] || [ "$_firmware" -eq "5" ]; then
	acRules="$(cru l | grep "yamon")"
else
	acRules="$(crontab -l)"
fi

Send2Log "crontab: $(IndentList "$acRules")" 0
Send2Log "blocked: $(IndentList "$(iptables -L | grep blocked -B 2)")" 2
Send2Log "End of hour: append \`$tmplogFile\` to \`$dailyLogFile\`" 2
#contents of tmplog minus the header lines
tmplogContents=$(cat "$tmplogFile" | grep -v "<\(/\{0,1\}head\|html\|meta\|link\|script\|head\|body\|!--header--\)")

echo "$tmplogContents</div>" | sed -E "s~^ ([^<].*$)~<pre>\1</pre>~g" | sed -E "s~(^[^<].*$)~<p class='err'>\1</p>~g" >> "$dailyLogFile"

#use temp timestamps to catch the change of hour & date
tds=$(date +"%Y-%m-%d")
thr=$(date +"%H")
#reset the temporary log file
echo "<html lang='en'>
<head>
<meta http-equiv='cache-control' content='no-cache' />
<meta http-equiv='Content-Type' content='text/html;charset=utf-8' />
<link rel='stylesheet' href='//code.jquery.com/ui/1.12.1/themes/smoothness/jquery-ui.css'>
<link rel='stylesheet' type='text/css' href='https://usage-monitoring.com/current/css/normalize.css'>
<link rel='stylesheet' type='text/css' href='https://usage-monitoring.com/current/css/logs.css'>
<script src='https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js'></script>
<script src='https://ajax.googleapis.com/ajax/libs/jqueryui/1.12.1/jquery-ui.min.js'></script>
<script src='https://usage-monitoring.com/current/js/logs.js'></script>
</head>
<body>
<div id='header'> <!--header-->
<h1>Log for <span id='logDate'>$tds</span></h1> <!--header-->
<p>Show: <label><input class='filter' type='checkbox' name='no-errors' checked>Errors</label><label><input class='filter' type='checkbox' name='no-ll2' checked>Level 2</label><label><input class='filter' type='checkbox' name='no-ll1' checked>Level 1</label><label><input class='filter' type='checkbox' name='no-ll0'>Level 0</label></p> <!--header-->
</div> <!--header-->
<div class='hour-contents'><p>Hour: $thr</p>
" > "$tmplogFile"

Send2Log "End of hour: remove \`$rawtraffic_hr\`"
rm "$rawtraffic_hr" 

Send2Log "Processes: $(IndentList "$(ps | grep -v grep | grep $d_baseDir)")"

LogEndOfFunction
