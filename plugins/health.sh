#!/bin/bash
# Verifies that the bar is really drawn and restarts SketchyBar if not.
# Symptom: after a display change during sleep the process lives, drawing=on, but no
# item has a window (empty bounding_rects). --reload does not recover it; a restart does.
# At most one restart per 5 minutes. Log: $SBD_CACHE/health.log
. "${0%/*}/../lib/env.sh"
LOG="$SBD_CACHE/health.log"; ITEM="${HEALTH_ITEM:-clock}"
for _ in 1 2 3 4 5; do   # queries sometimes come back empty; only five misses in a row count
  sketchybar --query "$ITEM" 2>/dev/null | grep -q '"origin"' && exit 0
  sleep 1
done
pgrep -qx sketchybar || exit 0   # not running: launchd brings it back
now=$(date +%s); last=$(cat "$SBD_CACHE/health.last" 2>/dev/null || echo 0)
if [ $(( now - last )) -lt 300 ]; then
  echo "$(date '+%F %T') no windows, restart skipped (last ${last}s ago)" >> "$LOG"; exit 0
fi
echo "$now" > "$SBD_CACHE/health.last"
LABEL=$(launchctl list 2>/dev/null | awk '/sketchybar/{print $3; exit}')
echo "$(date '+%F %T') no windows after ${SENDER:-check}, restarting (${LABEL:-no launchd label})" >> "$LOG"
if [ -n "$SB_RESTART_CMD" ]; then eval "$SB_RESTART_CMD"   # tests
elif [ -n "$LABEL" ]; then launchctl kickstart -k "gui/$(id -u)/$LABEL"; fi
