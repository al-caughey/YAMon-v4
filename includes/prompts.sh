##########################################################################
# Yet Another Monitor (YAMon)
# Copyright (c) 2013-present Al Caughey
# All rights reserved.
#
# utility functions used by install and setup
#
# History
# 2020-01-26: 4.0.7 - no changes
# 2020-01-03: 4.0.6 - added pad_length in UpdateConfig
# 2019-12-23: 4.0.5 - removed extra space before # Added in UpdateConfig()
# 2019-11-24: 4.0.4 - no changes (yet)
# 2019-06-18: development starts on initial v4 release
#
##########################################################################

SetupLog(){
	[ "${2:-0}" -lt "${_loglevel:-0}" ] && return
	echo -e "<section class='ll${2:-0}'><article class='dt'>$(date +"%T")</article><article class='msg'>$1</article></section>" >> "$setupLogFile"
}

Prompt(){ 
    local resp='' 
    local vn=$1
    eval nv=\"\$$vn\"
    local df="$4"
    local regex="$5"
    _qn=$(($_qn + 1))
    local p2="$2"
    local topic="$6"
    [ -z  "$topic" ] && topic="$vn"
    echo -e "
#$_qn. $p2" >&2
    p3="$(echo -e "    $3
    "| sed -re 's~[\t]+~    ~g')
    "
    if [ -z "$nv" ] && [ -z "$df" ] ; then 
        nv='n/a' 
        df='n/a' 
        readStr="    Enter your preferred value: " 
    elif [ -z "$df" ] ; then 
        readStr="${p3}Hit <enter> to accept the current value (\`$nv\`),
      or enter your preferred value: " 
    elif [ -z "$nv" ] ; then 
        nv='n/a' 
        readStr="${p3}Hit <enter> to accept the default (\`$df\`),
      or enter your preferred value: " 
    elif [ "$df" == "$nv" ] ; then 
        readStr="${p3}Hit <enter> to accept the current/default value (\`$df\`),
      or enter your preferred value: " 
    else 
        readStr="${p3}Hit <enter> to accept the current value: \`$nv\`, \`d\` for the default (\`$df\`)
      or enter your preferred value: " 
    fi 
    local tries=0 
    while true ; do 
        read -p "$readStr" resp
        [ ! "$df" == 'n/a' ] && [ "$resp" == 'd' ] && resp="$df" && break
        [ ! "$nv" == 'n/a' ] && [ -z "$resp" ] && resp="$nv" && break
        [ "$nv" == 'n/a' ] && [ ! "$df" == 'n/a' ] && [ -z "$resp" ] && resp="$df" && break
        if [ -n "$regex" ] ;  then
            ig=$(echo "$resp" | grep -E $regex)
            [ ! "$ig" == '' ] && [ "$resp" == 'n' ] || [ "$resp" == 'N' ] && resp="0" && break
            [ ! "$ig" == '' ] && [ "$resp" == 'y' ] || [ "$resp" == 'Y' ] && resp="1" && break
            [ ! "$ig" == '' ] && break
        else
            break
        fi
        tries=$(($tries + 1))
        if [ "$tries" -eq "3" ] ; then
            echo "*** Strike three... you're out!" >&2
            exit 0
        fi
        SetupLog "Bad value for $vn --> $resp" 2
        echo "
    *** \`$resp\` is not a permitted value for this variable!  Please try again.
     >>> For more info, see http://usage-monitoring.com/help/?t=$topic" >&2
    done
    eval $vn=\"$resp\"
	SetupLog "Prompt: $p2 --> $resp" 2
    UpdateConfig $vn "$resp"
}
UpdateConfig(){
    local vn=$1
    local nv=$2
    [ "${vn:0:2}" == 't_' ] && return
    [ -z "$nv" ] && eval nv="\$$vn"
    SetupLog "UpdateConfig: $vn --> $nv" 2
    local sv="$vn=.*#"
    local rv="$vn=\'$nv\'"
    local sm=$(echo "$configStr" | grep -o $sv)
    local l2=${#rv}
    #SetupLog "UpdateConfig: sm--> $sm ($l1)// rv--> $rv ($l2)" 2
    local spacing='==================================================='
	local pad_length=$((46-$l2+1))
	[ "$pad_length" -lt 1 ] && pad_length=1
	local pad=${spacing:0:$pad_length}
    if [ -z "$sm" ] ; then
        configStr="$configStr\n$vn='$nv'${pad//=/ }# Added"
    else
        configStr=$(echo "$configStr" | sed -e "s~$sv~$rv${pad//=/ }#~g")
    fi
}
