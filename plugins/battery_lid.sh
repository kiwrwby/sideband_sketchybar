#!/bin/bash
# Popup button: keep the Mac awake with the lid closed (caffeinate), or stop doing so.
# The pid is stored; no admin rights needed.
. "${0%/*}/../lib/env.sh"
PIDF="$SBD_CACHE/caffeinate.pid"
is_ours() { [ "$(ps -p "$1" -o comm= 2>/dev/null | sed 's|.*/||')" = caffeinate ]; }   # pids get reused after a reboot
if is_ours "$(cat "$PIDF" 2>/dev/null)"; then
  kill "$(cat "$PIDF")"; rm -f "$PIDF"
else
  ( nohup caffeinate -dims >/dev/null 2>&1 & echo $! > "$PIDF" ); sleep 0.2
fi
SENDER=routine /bin/bash "$SBD_PLUGINS/battery.sh"
