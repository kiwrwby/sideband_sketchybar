#!/bin/bash
# Battery item and popup. Every 30 s and on power events. Modes: bar | percent | hidden.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"; . "$SBD_ROOT/lib/battery.sh"
sbd_battery
PCT=${BAT_PCT:-100}

# Bar
case "$BATTERY_MODE" in
  hidden) sketchybar --set bat drawing=off; exit 0 ;;
  percent) sketchybar --set bat drawing=on icon.drawing=off label.drawing=on label="${BAT_PCT:-—}%" label.color="$BAT_COLOR" ;;
  *)
    sketchybar --set bat drawing=on icon.drawing=on icon.color="$BAT_COLOR" label.drawing=off
    n=$(( (PCT + 19) / 20 )); a=()
    for i in 1 2 3 4 5; do a+=(--set bat.$i drawing=on background.color=$([ $i -le $n ] && echo "$BAT_COLOR" || echo "$LINE")); done
    sketchybar "${a[@]}" ;;
esac

# Popup
if   [ $BAT_FULL = 1 ];     then POW="AC  full";      PWC=$TEXT;   R="—"; RC=$TEXT2
elif [ $BAT_CHARGING = 1 ]; then POW="AC  charging";  PWC=$ACCENT; R="${BAT_REMAIN:-—} until full"; RC=$TEXT
elif [ $BAT_AC = 1 ];       then POW="AC";            PWC=$TEXT;   R="—"; RC=$TEXT2
else POW="battery"; PWC=$TEXT; R="${BAT_REMAIN:-calculating}"; RC=$TEXT; [ "$BAT_STATE" = critical ] && RC=$ERR; fi
[ "$BAT_STATE" = low_power ] && POW="$POW  low power"
PC=$TEXT; [ "$BAT_STATE" = critical ] && PC=$ERR
if [ "$(ps -p "$(cat "$SBD_CACHE/caffeinate.pid" 2>/dev/null)" -o comm= 2>/dev/null | sed "s|.*/||")" = caffeinate ]; then LID="stays awake when closed"; LC=$TEXT; else LID="sleeps when closed"; LC=$TEXT2; fi
printf 'charge\t%s%%\t%s\t\npower\t%s\t%s\t\nleft\t%s\t%s\t\nlid\t%s\t%s\t@/bin/bash %s/battery_lid.sh\nopen\tBattery Settings ↗\t%s\topen "x-apple.systempreferences:com.apple.Battery-Settings.extension"\n' \
  "${BAT_PCT:-—}" "$PC" "$POW" "$PWC" "$R" "$RC" "$LID" "$LC" "$SBD_PLUGINS" "$TEXT2" \
  | nbsp2 | popup_rows bat BATTERY
a=(); for i in 0 1 2 3 4; do a+=(--set bat.p.$i icon.y_offset=$POPUP_KEY_DY); done
sketchybar "${a[@]}" 2>/dev/null
