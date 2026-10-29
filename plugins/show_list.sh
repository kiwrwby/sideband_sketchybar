#!/bin/bash
# Full list in a terminal window, for "+N more" popup rows.
#   show_list.sh <name>   shows $SBD_CACHE/<name>.all (port<TAB>text per line)
. "${0%/*}/../lib/env.sh"
SELF="$SBD_PLUGINS/show_list.sh"
if [ "$1" != run ]; then
  if [ -d /Applications/Ghostty.app ] && [ "$TERMINAL_APP" = Ghostty ]; then
    open -na /Applications/Ghostty.app --args --window-width=80 --window-height=28 -e /bin/bash -c "'$SELF' run $1"
  else open -t "$SBD_CACHE/$1.all"; fi
  exit 0
fi
GP=$(ps -o ppid= -p $PPID | tr -d ' ')
F="$SBD_CACHE/$2.all"; T=$(tr '[:lower:]' '[:upper:]' <<<"$2")
printf '\n  %s  (%s)\n\n' "$T" "$(grep -c . "$F")"; awk -F'\t' '{printf "  :%-6s %s\n", $1, $2}' "$F"
printf '\n  press any key to close'; read -rsn1
ps -o command= -p "$GP" | grep -q 'ghostty.*show_list' && kill "$GP"
