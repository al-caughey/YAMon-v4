#!/bin/sh

set -o pipefail 

d_baseDir=$(cd "$(dirname "$0")" && pwd)
showEcho=1
source "${d_baseDir}/includes/shared.sh"

cver=$(echo "$_version" | cut -d'.' -f3 )
nver="${_version%%$cver}$(($cver+1))"

#update the version number in version.sh
sed -i "s~^_version='$cver'~" "_version='$nver'" "${d_baseDir}/includes/version.sh" 

urf(){
	local p2f=$1
	[ -f "${d_baseDir}/$p2f$nver.sh" ] && cp "${d_baseDir}/$p2f$nver.sh" "${d_baseDir}/$p2f$nver.old" 
	cp "${d_baseDir}/$p2f$_version.sh" "${d_baseDir}/$p2f$nver.sh" 
}

urf 'setup'
IFS=$'\n'
lof=$(find ${d_baseDir} | grep '.sh')

tar -cf "${_path2bu}v$_version-${_ds}.tar.gz" $lof 2>/dev/null 
sed -i "s~^# History~# History\n# $_ds: $nver - no changes~g" $lof
sed -i "s~^* History~* History\n  > $_ds: $nver\n    + ~g" "${d_baseDir}/changes.log"
echo "done"