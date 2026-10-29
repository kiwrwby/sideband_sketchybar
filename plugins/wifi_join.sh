#!/bin/bash
# Join a saved network from the Wi-Fi popup: wifi_join.sh <popup row index> <network>
# The status shows at the right end of the row: "·", "··", "···" while trying, "failed"
# for 3 s on error. networksetup exits 0 even when it fails, so the verdict is its
# output: any text means failure. 20 s limit. Uses the keychain password.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
LOCK="$SBD_CACHE/wifi_join.lock"; ST="$SBD_CACHE/wifi_join.st"
# A lock whose pid now belongs to another program is stale.
if [ -e "$LOCK" ] && ps -p "$(cat "$LOCK")" -o command= 2>/dev/null | grep -q "wifi_join"; then exit 0; fi
echo $$ > "$LOCK"; echo $$ > "$ST"
row="wifi.p.$1"; W=$POPUP_W_DEFAULT
IF=$(cat "$SBD_CACHE/wifi_if" 2>/dev/null); IF=${IF:-en0}
show() { PX=(); popup_right "$row" "$1" "$2" "$W"; sketchybar "${PX[@]}"; }
clear_st() { sketchybar --set "$row" background.image.drawing=off; }
CMD=(networksetup -setairportnetwork "$IF" "$2")
[ -n "$WIFI_JOIN_DRY" ] && { printf '%q ' "${CMD[@]}"; echo; rm -f "$LOCK"; exit 0; }   # tests
( while :; do for d in '·' '··' '···'; do show "$d" "$TEXT3"; sleep 0.4; done; done ) & dots=$!
trap 'kill $dots 2>/dev/null' EXIT TERM   # the dots loop must not outlive this script
out=$(with_timeout 20 "${CMD[@]}" 2>&1); rc=$?
kill $dots 2>/dev/null; wait $dots 2>/dev/null
if [ $rc = 0 ] && [ -z "$out" ]; then clear_st; rm -f "$LOCK"; SENDER=forced /bin/bash "$SBD_PLUGINS/wifi.sh"; exit 0; fi
show failed "$ERR"; rm -f "$LOCK"
sleep 3; [ "$(cat "$ST" 2>/dev/null)" = $$ ] && clear_st   # a newer attempt owns the row
