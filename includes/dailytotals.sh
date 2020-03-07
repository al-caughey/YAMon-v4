##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# functions to tally traffic from iptables
#
# Run - manually from calculate-daily-totals or by cron from end-of-day
#
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - replaced all non-alpha chars with _ in t_interfaces (rather than just -) in CalculateInterfaceTotals
# 2019-12-23: 4.0.5 - added CalculateInterfaceTotals; removed brace brackets around memory
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-11-17: re-added DigitAdd to prevent overfollow errors
# 2019-06-18: development starts on initial v4 release
#
# To Do:
#
##########################################################################

CalculateDailyTotals(){

	CalculateInterfaceTotals(){
		Send2Log "CalculateInterfaceTotals: start" 2
		#To-do: check value of $_interfaces
		IFS=$','
		for ifn in $_interfaces
		do	
			local vn=$(echo $ifn | sed "s~[^a-z0-9]~_~ig")
			eval "${vn}_down=0"
			eval "${vn}_up=0"
		done

		IFS=$'\n'
		local interfaceData=$(cat "$file2Total" | grep -e "^Totals({.*})$")
		for line in $interfaceData
		do
			[ -z "$line" ] && continue
			local hour=$(echo "$line" | grep -o "hour[^,]\{0,\}" | cut -d':' -f2)
			IFS=$','
			for ifn in $_interfaces
			do
				local vn=$(echo $ifn | sed "s~[^a-z0-9]~_~ig")
				local ifv=$(echo "$line" | grep -o "\b$ifn\b[^}]\{0,\}" | cut -d':' -f2)
				local t_d=$(echo "${ifv//\"/}" | cut -d',' -f1)
				local t_u=$(echo "${ifv//\"/}" | cut -d',' -f2)
				local o_d=$(eval echo "\$${vn}_down")
				local o_u=$(eval echo "\$${vn}_up")

				eval "${vn}_down=$((${o_d:-0} + ${t_d:-0}))"
				eval "${vn}_up=$((${o_u:-0} + ${t_u:-0}))"
				Send2Log "  $ifn: $o_d + ${t_d:-0} = $(eval echo "\$${vn}_down") / $o_u + ${t_u:-0} = $(eval echo "\$${vn}_up")"
			done
			IFS=$'\n'
		done
		IFS=$','
		local retstr=""
		local retstr=""
		for ifn in $_interfaces 	
		do	
			local vn=$(echo $ifn | sed "s~[^a-z0-9]~_~ig")
			retstr=$(echo "$retstr{\"n\":\"$vn\",\"t\":\"$(eval echo "\$${vn}_down"),$(eval echo "\$${vn}_up")\"},")
		done

		echo "\"interfaces\":'[${retstr%,}]'"
		unset IFS
	}

	[ -n "$1" ] && totalsDate="$1"
	if [ -n "$2" ] ; then
		_intervalDataFile="$2"
		_path2CurrentMonth="$(dirname "$_intervalDataFile")/"
	fi
	
	if [ ! -f "$_intervalDataFile" ] ; then
		Send2Log "CalculateDailyTotals: couldn't find \`$_intervalDataFile\`?!?" 3
		CheckIntervalFiles
	fi 
	
	[ -z "$totalsDate" ] && totalsDate="$_ds"

	echo -e "\n//Totals for $totalsDate"  >> "$_intervalDataFile"
	day=$(echo $totalsDate | cut -d- -f3)

	file2Total="${_path2CurrentMonth}hourly_${totalsDate}.js"

	Send2Log "CalculateDailyTotals: start --> $file2Total (param: $1)" 2
	if [ ! -f "$file2Total" ] ; then
		Send2Log "CalculateDailyTotals: couldn't find \`$file2Total\`?!?" 3
		echo "// couldn't find \`$file2Total\`?!?" >> "$_intervalDataFile"
		exit
	fi 
	hourlyData=$(cat "$file2Total" | grep -e "^hourlyData4({.*})$")
	IFS=$'\n'

	while [ 1 ] ;
	do
		local fl=$(echo "$hourlyData" | head -n 1)
		[ -z "$fl" ] && break
		id=$(GetField "$fl" 'id')
		[ -z "$id" ] && break #should be unnecessary?!?
		entries4id=$(echo "$hourlyData" | grep "$id")
		local total_down=0
		local total_up=0
		local total_unlimited_down=0
		local total_unlimited_up=0
		#Send2Log "CalculateDailyTotals: entries4id:$(IndentList "$entries4id")"
		for line in $entries4id 
		do
			[ -z "$line" ] && break
			Send2Log "CalculateDailyTotals: line:$line"
			traffic=$(GetField "$line" 'traffic')
			down=$(echo "$traffic" | cut -d, -f1)
			up=$(echo "$traffic" | cut -d, -f2)
			unlimited_down=$(echo "$traffic" | cut -d, -f3)
			unlimited_up=$(echo "$traffic" | cut -d, -f4)
			total_down=$(DigitAdd ${total_down:-0} ${down:-0})
			total_up=$(DigitAdd ${total_up:-0} ${up:-0} )
			total_unlimited_down=$(DigitAdd ${total_unlimited_down:-0} ${unlimited_down:-0} )
			total_unlimited_up=$(DigitAdd ${total_unlimited_up:-0} ${unlimited_up:-0} )
		done	

		deviceTotals="totalDaily({ \"day\":\"$day\", \"id\":\"$id\", \"traffic\":\"$total_down,$total_up,$total_unlimited_down,$total_unlimited_up\" })"
		echo "${deviceTotals/,0,0\"/\"}" >> "$_intervalDataFile"
		hourlyData=$(echo "$hourlyData" | grep -v "$id")
		local grand_total_down=$(DigitAdd ${grand_total_down:-0} ${total_down:-0} )
		local grand_total_up=$(DigitAdd ${grand_total_up:-0} ${total_up:-0} )
		local grand_total_unlimited_down=$(DigitAdd ${grand_total_unlimited_down:-0} ${total_unlimited_down:-0} )
		local grand_total_unlimited_up=$(DigitAdd ${grand_total_unlimited_up:-0} ${total_unlimited_up:-0} )
	done
	local interfaceTotals=$(CalculateInterfaceTotals)
	grandTotals="GrandTotalDaily({ \"day\":\"$day\", \"traffic\":\"${grand_total_down:-0},${grand_total_up:-0},${grand_total_unlimited_down:-0},${grand_total_unlimited_up:-0}\", $interfaceTotals })"
	
	echo "${grandTotals/,0,0\"/\"}" >> "$_intervalDataFile"
	
	sed -i "s~var monthly_updated.\{0,\}$~var monthly_updated=\"$_ds $(date +"%T")\"~" "$_intervalDataFile"

}