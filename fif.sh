#!/bin/sh

d_baseDir=$(cd "$(dirname "$0")" && pwd)
echo -en "\nFind in File:  "
[ -z "$1" ] && echo -e " Error - must include one or two parameter(s)\n\tRun fif.sh -h for help\n" && exit 0
[ "$1" == '-h' ] && echo " fif '<pattern>' -or- fif '<path>' '<pattern>'
 - fif '<pattern>': the text to search for within \`${d_baseDir}\`
 - fif '<pattern>' '<excluding>': the text to search for within \`${d_baseDir}\` excluding the specified pattner 
 - fif '<pattern>' '<excluding>' '<path>': the text to search for within the specified path with the excluded pattern
 NB - add quotes if the path or pattern includes spaces
 " && exit 0
 #echo $1 / $2 / $3
 
pattern="$1"
excluding="${2:-\.log|\.js|\.html|\.gz}"
path="${3:-$d_baseDir}"

[ ! -d "$path" ] && echo -e " Error - \`$path\` does not exist?!?\n" && exit 0

echo "Searching for \`$pattern\` in \`$path\` (excluding \`$excluding\`):"
[ "$pattern" == "<errors>"  ] && pattern='^[a-zA-Z/]'
#egrep -rn "$path" -e "$pattern" | egrep -v "$excluding" | sed -e "s~$d_baseDir/~ > ~" -e "s~:\s\{0,\}~ -> ~g" -e "s~--> ~- line:~"
#egrep -rn "$path" -e "$pattern"
grep -rn "$path" -Ee "$pattern" | grep -Ev "\b$excluding\b" | sed -e "s~$d_baseDir/~ > ~" -e "s~:[ \s\t]\{0,\}~ -> ~g" -e "s~--> ~- line:~"

[ "$?" -eq "1" ] && echo -e " No matches for \`$pattern\`\n" && exit 0
echo ''