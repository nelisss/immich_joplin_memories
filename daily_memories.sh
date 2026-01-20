#!/bin/bash

### Obtain variables from .env
source .env

date1=$( date +"%A %d %B %Y" )
date2=$( date +"%Y-%m-%d" )

### Obtain Joplin notes on this date
get_joplin() {
    year=$1
    daysago=$(( $1 * 365 ))
    result=$( curl -s "${joplin_address}/search?query=created:day-${daysago}%20-created:day-$(( $daysago - 1 ))&fields=title,body" ) # Get results from Joplin
    titles=$( echo "${result}" | grep -oP "(?<=\"title\":\").*?(?=\",)" ) # Get titles from json result
    found=$( if [ $? -ne 1 ]; then echo "true"; else echo "false"; fi ) # Check if there are any results
    titles=$( echo "${titles}" | sed 's/\%/\%\%/g' ) # Escape %
    bodies=$( echo "${result}" | grep -oP "(?<=\"body\":\").*?(?=\"})" ) # Get bodies from json result
    bodies=$( echo "${bodies}" | sed 's/\n*!\[\](dayone-moment:.*)//g' ) # Remove references to day one photos
    bodies=$( echo "${bodies}" | sed 's/\%/\%\%/g' ) # Escape %
    bodies=$( echo "${bodies}" | awk '{$1=$1};1' ) # Remove leadings & trailing whitespace
    if [[ "$found" == true ]]; then
        content=$( 
            printf "## $i $( if [[ "$i" == 1 ]]; then echo -n "year"; else echo -n "years"; fi ) ago:\n"
            linenum=1
            while read line; do
                if [[ ${linenum} != 1 ]]; then
                    printf "\n\n%s\n" "### $line"
                else
                    printf "%s\n" "### $line"
                fi
                printf "$(sed -n ${linenum}p <<< "$bodies")"
                linenum=$(( linenum + 1 ))
            done <<< "$titles"
        )
        content=$( echo -e "$content" | sed -E 's/^([^ .#:-]+)$/**\1**/' ) # Make single lines without interpunction bold
        content=$( echo -e "$content" | sed -E 's/^# (.*)$/**\1**/' ) # Replace headings with bold
        content=$( echo -e "$content" | sed -E 's/(.+)/\n\1/g' ) # Add newline to every line
        echo -e "$content"
    fi
}

### Obtain Immich memories on this date
get_immich() {
    api_key="${immich_api_key}"
    container_name="${immich_container_name}"
    internal_address="${immich_internal_address}"
    external_address="${immich_external_address}"
    today="$( date +%Y-%m-%d )"
    current_year="$( date +%Y )"

    if ( docker ps | grep "${container_name}" > /dev/null ) && ( docker exec ${container_name} curl -s "${internal_address}" > /dev/null ); then
        memories=$( docker exec ${container_name} curl -s -H "x-api-key:${api_key}" "${internal_address}/api/memories" ) # Get all memories
        ids_today="$( echo "$memories" | grep -oP "(?<=\"id\":\")[^}]*(?=\",\"showAt\":\"${today})" | grep -oP "[a-z0-9\-]*(?=\",\"createdAt)" )" # Get ids of memories that are meant to be shown today
        while read -r id; do
            memories_content=$( docker exec ${container_name} curl -s -H "x-api-key:${api_key}" "${internal_address}/api/memories/${id}" ) # Get content of memory
            memories_year=$( echo "$memories_content" | grep -oP "(?<=\"memoryAt\":\")[^\"]*(?=\",\"showAt\")" | grep -oP "[0-9]{4}" ) # Get year of memory
            memories_link="${external_address}/memory?id=${id}" # Get link to memory
            years_ago=$(( current_year - memories_year )) # Get the number of years ago
            if [[ "$years_ago" == 1 ]]; then echo "## [${years_ago} year ago](${memories_link})"; else echo -e "\n## [${years_ago} years ago](${memories_link})"; fi
            memories_assets=$( echo "$memories_content" | grep -oP "(?<=assets\":\[).*(?=\]\})" | grep -oP "(?<=\"id\":\")[^\"]*(?=\",\"createdAt\":)" )
            while read -r asset_id; do
                echo -e "\n![](${external_address}/api/assets/${asset_id}/thumbnail?apiKey=${api_key})"
            done <<< "$memories_assets"
        done <<< "$ids_today"
    else
        echo "Immich server not running or address inaccessible."
        exit 1
    fi
}

### Send mail with memories
cat << EOM | pandoc -s -f markdown -t html --metadata title="Daily memories" | mail -M "text/html" -s "Memories ($date2)" -r "Memories <${sender_email}>" ${destination_email}

Good morning!

Today is ${date1}.

# Today's memories

$( get_immich )

# On this day in Joplin:

$( 
for i in $(seq 1 25); do
    get_joplin $i 
done 
)

Kind regards,
Me 
EOM
