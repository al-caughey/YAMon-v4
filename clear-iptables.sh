#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# clears YAMon entries from iptables & ip6tables
# run: manually
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - no changes
# 2019-12-23: 4.0.5 - no changes
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

function ClearTables(){
	cmd="$1"
	tables="FORWARD,INPUT,OUTPUT"
	echo " > Clearing tables:"
	IFS=$','
	for tt in $tables
	do
		oe=$($cmd -nL "$tt" --line-numbers | grep "$str")
		[ -z "$oe" ] && echo "   * Nothing to clear in $tt" && continue
		rn=$(echo "$oe" | awk '{ print $2 }')
		echo "   * Deleting $rn from $tt"
		dup_num=$(echo "$oe" | awk '{ print $1 }')
		[ -n "$rn" ] && eval $cmd -D "$tt" $dup_num
	done
}

function FlushChains(){
	cmd="$1"
	echo -e "\n > Flushing chains in $cmd:"
	chainlist=$($cmd -L | grep $str | grep Chain)
	[ -z "$chainlist" ] && echo "   * Nothing to flush" && return
	IFS=$'\n'
	for ch in $chainlist
	do
		wc=$(echo $ch | cut -d' ' -f2)
		echo "   * $wc"
		$cmd -F "$wc"
	done
}

function DeleteChains(){
	cmd="$1"
	echo -e "\n > Deleting chains in $cmd:"
	chainlist=$($cmd -L | grep $str | grep Chain)
	[ -z "$chainlist" ] && echo "   * Nothing to flush" && return
	IFS=$'\n'
	for ch in $chainlist
	do
		wc=$(echo $ch | cut -d' ' -f2)
		echo "   * $wc"
		$cmd -X "$wc"
	done
}

str='YAMONv40'
commands='iptables,ip6tables'
IFS=$','
for c in $commands
do
	echo -e "\n*******************\nCleaning entries for $c:"
	ClearTables $c

	FlushChains $c

	DeleteChains $c
	IFS=$','
done
echo -e "\n*******************\nAll '$str' entries have been removed from iptables & ip6tables\n\n"
