#!/bin/bash
# First values, daemons, then show the bar.
unset -f sb sb_flush 2>/dev/null
sb() { command sketchybar "$@"; }
sb_flush() { :; }

# Run each plugin once, in parallel, before the bar appears. SB_BOOT=1 makes them set
# only what is visible on the bar (no popup rows, no width animation).
fill() { SB_BOOT=1 NAME=$1 SENDER=${3:-forced} INFO="$4" bash "$P/$2" >/dev/null 2>&1 & }
FRONT=$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | perl -ne 'print /^"LSDisplayName"="(.*)"$/ ? $1 : /^"([^"]+)"/ ? $1 : "" if $. == 1')
fill clock clock.sh
fill wifi wifi.sh routine
fill bat battery.sh
fill agent agents.sh
flag_on "$SYSTEM_MENU" && fill cpu system.sh
flag_on "$SHOW_MEDIA" && { fill vol volume.sh; fill media media.sh; }
fill pilo pilo.sh; fill ts tailscale.sh; fill ports ports.sh; fill docker docker.sh; fill notif notif.sh; fill ci ci.sh
[ -n "$FRONT" ] && flag_on "$SHOW_FRONT_APP" && fill front_app front_app.sh front_app_switched "$FRONT"
for _ in $(seq 40); do [ -z "$(jobs -r)" ] && break; sleep 0.05; done   # wait at most 2s; late values fill in place

# Daemons. Each is restart-safe and exits when SketchyBar does.
flag_on "$SYSTEM_MENU" && flag_on "$CAT_ANIMATE" && ! sbd_reduce_motion && sbd_start cat /bin/bash "$P/cat.sh" || sbd_stop cat
if flag_on "$WORDMARK_ANIMATE" && [ "$WM_STATIC" != 1 ]; then sbd_start wordmark /bin/bash "$P/wordmark.sh"
else sbd_stop wordmark; fi
if flag_on "$SHOW_MEDIA"; then
  sbd_start media_watch /bin/bash "$P/media_watch.sh"
  sbd_start audio_watch "$SBD_HELPERS/audio" watch "SBD_BAR_PID=$SBD_BAR_PID NAME=vol SENDER=routine /bin/bash '$P/volume.sh'"
fi

command sketchybar --bar y_offset=$BAR_TOP
trap - EXIT
command sketchybar --update
command sketchybar --query displays | md5 > "$SBD_CACHE/displays"   # popup_guard compares against it
date +%s > "$SBD_CACHE/ready"
