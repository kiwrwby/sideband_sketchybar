#!/bin/bash
# Running container count, with a popup list. Hidden when none run or Docker is absent.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
DK=$(find_cli docker)
if [ -z "$DK" ] || ! flag_on "$SHOW_DOCKER" true; then sketchybar --set docker drawing=off; exit 0; fi
LIST=$(with_timeout 5 "$DK" ps --format '{{.Names}}\t{{.Status}}' 2>/dev/null)
N=$(grep -c . <<<"$LIST")
while IFS=$'\t' read -r name status; do
  [ -n "$name" ] && printf '%s\t%s\t%s\topen -a '"'"'%s'"'"'\n' "${status%% *}" "$name" "$TEXT" "$TERMINAL_APP"
done <<<"$LIST" | popup_rows docker DOCKER
if [ "$N" -gt 0 ]; then sketchybar --set docker drawing=on label="$N"; else sketchybar --set docker drawing=off; fi
