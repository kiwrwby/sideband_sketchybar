#!/bin/bash
# Battery state from pmset. English output regardless of system language.
#   sbd_battery            sets BAT_PCT BAT_AC BAT_CHARGING BAT_FULL BAT_REMAIN BAT_STATE BAT_COLOR
#   sbd_battery_color <state>  colour for a state, honouring the BATTERY_COLOR_* overrides
# BAT_STATE: low_power > charging > critical > normal
sbd_battery_color() {
  local v
  case "$1" in
    low_power) v=${BATTERY_COLOR_LOW_POWER:-auto};  [ "$v" = auto ] && v=$WARN ;;
    charging)  v=${BATTERY_COLOR_CHARGING:-auto};   [ "$v" = auto ] && v=$ACCENT ;;
    critical)  v=${BATTERY_COLOR_CRITICAL:-auto};   [ "$v" = auto ] && v=$ERR ;;
    *)         v=${BATTERY_COLOR_NORMAL:-auto};     [ "$v" = auto ] && v=$TEXT ;;
  esac
  printf '%s' "$v"
}
sbd_battery() {
  local snap low
  snap=${1:-$(pmset -g batt)}
  low=$(pmset -g live 2>/dev/null | awk '$1 == "lowpowermode" {print $2; exit}')
  BAT_PCT=$(grep -Eo '[0-9]+%' <<<"$snap" | head -1); BAT_PCT=${BAT_PCT%\%}
  BAT_AC=0;       grep -q 'AC Power' <<<"$snap" && BAT_AC=1
  BAT_CHARGING=0; grep -q '; charging' <<<"$snap" && BAT_CHARGING=1
  BAT_FULL=0;     { grep -q 'charged' <<<"$snap" || { [ $BAT_AC = 1 ] && [ "${BAT_PCT:-0}" -ge 100 ]; }; } && BAT_FULL=1
  BAT_REMAIN=$(grep -Eo '[0-9]+:[0-9]+ remaining' <<<"$snap" | cut -d' ' -f1)
  if [ "$low" = 1 ]; then BAT_STATE=low_power
  elif [ $BAT_CHARGING = 1 ]; then BAT_STATE=charging
  elif [ "${BAT_PCT:-100}" -le "${BATTERY_CRITICAL_PCT:-20}" ] && [ $BAT_AC = 0 ]; then BAT_STATE=critical
  else BAT_STATE=normal; fi
  BAT_COLOR=$(sbd_battery_color "$BAT_STATE")
}
