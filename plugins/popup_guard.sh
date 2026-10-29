#!/bin/bash
# Closes popups when the front app, space or display layout changes.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"

# display_change also fires when a window moves to another display. Act only when
# the layout really changed, otherwise a popup that was just opened closes again.
if [ "$SENDER" = display_change ]; then
  now=$(sketchybar --query displays | md5)
  [ "$now" = "$(cat "$SBD_CACHE/displays" 2>/dev/null)" ] && exit 0
  echo "$now" > "$SBD_CACHE/displays"
  # Measure again so the notch width follows (main display switching between a
  # notch display and an external one). No full reload.
  . "$SBD_ROOT/lib/display.sh"; sbd_measure_display
  sketchybar --bar notch_width=$NOTCH_W
  flag_on "$SHOW_MEDIA" && sketchybar --trigger media_update
fi

# After a display change or wake the bar sometimes has no windows. Check shortly
# after and restart if needed (health.sh limits itself to one restart per 5 minutes).
case "$SENDER" in display_change|system_woke) ( sleep 6; SENDER="$SENDER" nohup /bin/bash "$SBD_PLUGINS/health.sh" >/dev/null 2>&1 & ) ;; esac

# The Wi-Fi scan app has no window but briefly becomes the front app. Keep the popup.
[ "$SENDER" = front_app_switched ] && case "$INFO" in "sideband Wi-Fi Scan"|WifiScan) exit 0 ;; esac
popup_close_all
