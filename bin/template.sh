#!/bin/bash

USAGE="
$(basename "$0") [-h] -a ACCOUNT [-t TEMPLATE]
  -h          Print this help message
  -F FIXED    Account to query LastPass for.
              FIXED should be of the format: 'FIXED STRING'='PREFIX' where 'FIXED STRING'
              is the actual LastPass entry name (equivalent to \`lpass\`'s \`-F\`) and
              'PREFIX' is the prefix appended to the returned values for substitution in
              the template file (using envsubst)
"

declare -A FIXED

while getopts ":F:t:h" OPT; do
  case $OPT in
    F)
      eval "$(echo $OPTARG | awk -F= '{ print "FIXED["$1"]=\""$2"\"" }')"
      ;;
    t)
      TEMPLATE=$OPTARG
      ;;
    h)
      echo "$USAGE"
      exit
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo -e "$USAGE" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      echo -e "$USAGE" >&2
      exit 1
      ;;
  esac
done

if [[ ${#FIXED[@]} -eq 0 ]]; then
  echo -e "$USAGE" >&2
  exit 1
fi

if [[ -z "$TEMPLATE" ]]; then
  echo "You must pass in a template!" >&2
  echo -e "$USAGE" >&2
fi

for i in "${!FIXED[@]}"; do
  SEARCH="$SEARCH -F \"$i\""
done

function fetch {
  SEARCH=$*
  # The `uniq` is in there because right now the format is printed for every field (so 2+ lines per match)
  bash -c "lpass show --format '{ \"MATCH\":\"%an\", \"KEY\":\"%au\", \"SECRET\":\"%ap\" }' ${SEARCH} | grep '^{.*}' | uniq"
}
export -f fetch

while read -r MATCH; do
  PREFIX=${FIXED[$(echo $MATCH | jq -r '.MATCH')]}
  export $(echo $MATCH | jq -r --arg PREFIX "$PREFIX" 'keys[] as $k | select($k != "MATCH") | "\($PREFIX)_\($k)=\(.[$k])"')
done < <(fetch "$SEARCH")

echo -e "$TEMPLATE" | envsubst

echo
