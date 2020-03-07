#!/bin/sh

d_baseDir=$(cd "$(dirname "$0")" && pwd)

check4Overflow(){
	local n=1
	local a=5
	local b=1
	local ob=0
	while [ true ] ; do 
		c=$(($a + $b))
		echo "$n --> $a + $b = $c"
		[ $c -lt $a ] || [ $c -lt $b ] && break #check for sum overflow
		ob=$b
		a=$(($a * 10 + $a))
		b=$(($b * 10 + $b))
		[ $b -lt $ob ] && break #check for value overflow
		[ $n -eq 32 ] && break #check for max digits 
		n=$(($n + 1))
	done
	
}

echo "# digits before integer overflow:"
check4Overflow
