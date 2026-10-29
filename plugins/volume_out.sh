#!/bin/bash
# Switch the output device from the volume popup.
#   volume_out.sh set <device id> <row>
#   volume_out.sh connect <bluetooth address> <row>
# Status at the right end of the row: "·", "··", "···" while trying, "failed" for 3 s.
# The verdict is helpers/bin/audio's exit code; 10 s limit. Clicks on other devices are
# ignored while one is in flight; clicking again after a failure retries at once.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
LOCK="$SBD_CACHE/vol_out.lock"; ST="$SBD_CACHE/vol_out.st"
# A lock whose pid now belongs to another program is stale.
if [ -e "$LOCK" ] && ps -p "$(cat "$LOCK")" -o command= 2>/dev/null | grep -q "volume_out"; then exit 0; fi
echo $$ > "$LOCK"; echo $$ > "$ST"
row="vol.ul.p.$(( $3 + 1 ))"; W=$POPUP_W_DEFAULT   # row 0 = mute, 1 = OUTPUT, 2.. = devices
show() { PX=(); popup_right "$row" "$1" "$2" "$W"; sketchybar "${PX[@]}"; }
clear_st() { sketchybar --set "$row" background.image.drawing=off; }
( while :; do for d in '·' '··' '···'; do show "$d" "$TEXT3"; sleep 0.4; done; done ) & dots=$!
trap 'kill $dots 2>/dev/null' EXIT TERM   # the dots loop must not outlive this script
with_timeout 10 "$SBD_HELPERS/audio" "$1" "$2"; rc=$?
kill $dots 2>/dev/null; wait $dots 2>/dev/null
if [ $rc = 0 ]; then clear_st; rm -f "$LOCK"; SENDER=routine /bin/bash "$SBD_PLUGINS/volume.sh"; exit 0; fi
show failed "$ERR"; rm -f "$LOCK"
sleep 3; [ "$(cat "$ST" 2>/dev/null)" = $$ ] && clear_st
