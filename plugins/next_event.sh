#!/bin/bash
# Next calendar event on the bar: "14:30 standup +8m", or "now" while it runs.
# The popup (TODAY) lists the unfinished timed events of today. CAL_NEXT=1 to enable.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
flag_on "$CAL_NEXT" || { sketchybar --set cal drawing=off; exit 0; }
EVENTS=$("$SBD_HELPERS/events" today 2>/dev/null)
while IFS=$'\t' read -r t title; do
  [ -n "$t" ] && printf '%s\t%s\t%s\topen -a Calendar\n' "$t" "$title" "$TEXT"
done <<<"$EVENTS" | popup_rows cal TODAY
L=$(head -n1 <<<"$EVENTS")
[ -z "$L" ] && { sketchybar --set cal drawing=off; exit 0; }
START="${L%%	*}"; TITLE="${L#*	}"
MIN=$(( ( $(date -j -f "%H:%M" "$START" +%s) - $(date +%s) ) / 60 ))
[ "$MIN" -gt "$CAL_WINDOW_MIN" ] && { sketchybar --set cal drawing=off; exit 0; }
[ "$MIN" -le 0 ] && WHEN=now || WHEN="+${MIN}m"
sketchybar --set cal drawing=on icon="$START" label="$TITLE $WHEN"
