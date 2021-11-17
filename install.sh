#!/bin/sh

##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# Script to download, install & setup YAMon3.x
#
#   Updated: 2020-01-11 - added L flag to follow symlinks when checking read permissions (about line 95)
#   Updated: 2019-10-26 - updated for v4.0
#   Updated: 2020-03-19 - change windows linefeeds to unix
##########################################################################

yget(){
	local dst="$1"
	local src="$2"
	#echo "yget: $src --> $dst"
	if [ ! -z "$bHasCurl" ] ; then
		curl -sk --max-time 15 -o "$dst" --header "Pragma: no-cache" --header "Cache-Control: no-cache" -A YAMon-Setup "$src"
		if [ ! -f "$dst" ] ; then
			echo "	 --> download failed?!? with curl... Trying again with wget"
			wget "$src" -qO "$dst"
		fi
	else
		#echo "wget $src" -qO "$dst"
		wget "$src" -qO "$dst"
		if [ ! -f "$dst" ] ; then
			echo "	 --> download $src failed?!? Trying again"
			wget "$src" -qO "$dst"
		fi
	fi
	 #change windows linefeeds to unix
	sed -i -e 's/\r$//' "$dst" #change windows linefeeds to unix
}

[ -x /usr/bin/clear ] && bCanClear=1
[ -x /usr/bin/curl ] && bHasCurl=1

YAMON='/opt/YAMon4/'
directory='current'
[ ! -z "$1" ] && directory="$1"

echo "
**************************************
   Welcome to the YAMon installer

   For installation tips & tricks, see
      https://usage-monitoring.com/install
	  
   Please report any issues to
      install@usage-monitoring.com
	  
**************************************
 "
echo "Would you like to install YAMon on your router?"
tries=0
readstr="Either
	- hit <enter> or \`y\` for yes, or \`n\` for no: "
while true; do
	read -p "$readstr" resp

	if [ -z "$resp" ] || [ "$resp" == 'y' ] || [ "$resp" == 'Y' ] ; then
		break
	elif [ "$resp" == 'n' ] || [ "$resp" == 'N' ] ; then
		echo "
*** Cancelling installation...  Hopefully you'll try again!
Please send questions to install@usage-monitoring.com.

"
		exit 0
	else
		readstr="
	Only \`y\` or \`n\` are permitted!
	Please try again: "
	fi
done

baseurl='https://usage-monitoring.com'

echo "

Please specify the fully qualified path to your
installation directory - e.g., \`$YAMON\`.
"
tries=0
readstr="	Either
	- hit <enter> to accept \`$YAMON\`, or
	- type your preferred installation location: "
while true; do
	read -p "$readstr" resp
	resp="${resp:-$YAMON}"
	YAMON="${resp%%/}/" # ensure the path ends with a single /
	#echo "YAMON: $YAMON"
	p2c=$(dirname "$YAMON")
	[ -z "${p2c%/}" ] && p2c="$YAMON"
	#echo "$p2c: $(ls -laL "$p2c" | grep ' .$' | awk '{print $1}')"
	
	if [ -z "$(ls -laL  "$p2c" | grep ' .$' | awk '{print $1}' | grep 'w')" ] ; then
		echo -e "\n    *** Un-oh... You do not have write permissions in '$p2c'!\n"
	elif [ -d "$YAMON" ] ; then
		break
	else
		mkdir -p "$YAMON"
		[ -d "$YAMON" ] && break
		echo -e "\n    *** The installation directory could not be created?!?\n"
	fi
	readstr="    Please try again: "
	tries=$(($tries + 1))
	if [ "$tries" -eq "3" ] ; then
		echo -e "\n\n*** Hmmm... three tries and still not working...\nPlease check the installation requirements and try again.\nSend screenshots, etc. to questions@usage-monitoring.com."
		exit 0
	fi
done

echo "
**************************************
Installing YAMon...
"

umversion="/tmp/yamonsetup.txt"
yget "$umversion" "$baseurl/$directory/YAMon4/Setup/gfmd4.0.php"
if [ ! -f "$umversion" ] ; then
	echo "
Installation Failed!... \`$umversion\` was not created...
the router likely does not have internet access.
Please check your settings and try again.
"
	exit 0
fi

rm $umversion

chmod +x "$YAMON"
[ -d "${YAMON}data" ] && chmod -R 666 "${YAMON}data"
sleep 1

_enableLogging=1
_log2file=1
_loglevel=0

[ ! -d "${YAMON}includes" ] && mkdir -p "${YAMON}includes"
getlatest="${YAMON}includes/getlatest.sh"
_ts=$(date +"%s")
yget "$getlatest" "$baseurl/$directory/YAMon4/Setup/includes/getlatest.sh?$_ts"
source "$getlatest"

param='verify'
chmod +x "${YAMON}compare.sh"
source "${YAMON}compare.sh"
sleep 5
echo "



Running setup...



	"
[ ! -z "$bCanClear" ] && clear
source "${YAMON}setup.sh"
