#!/bin/bash
# Tailscale capsule icon: 3x3 dots, lit pattern when connected, all dim when not.
# Popup: status, devices (this device bold; online Macs open screen sharing, other
# online devices copy their IP), admin link. Tailscale settings are never touched.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
PX_DIR="$SBD_CACHE/px"

# The capsule shows when either button is enabled. Called by both ports.sh and here.
capsule() {   # <tailscale present 0/1>
  if flag_on "$SHOW_PORTS" || [ "$1" = 1 ]; then
    sketchybar --set apps.cap background.drawing=on --set apps.pad drawing=on --set isl.gap width=$ISLAND_GAP
  else
    sketchybar --set apps.cap background.drawing=off --set apps.pad drawing=off --set isl.gap width=0
  fi
}
TS=$(find_cli tailscale || ls /Applications/Tailscale.app/Contents/MacOS/Tailscale 2>/dev/null)
if [ -z "$TS" ] || ! flag_on "$SHOW_TAILSCALE" true; then
  sketchybar --set ts drawing=off; capsule 0; exit 0
fi
capsule 1
J=$(with_timeout 5 "$TS" status --json 2>/dev/null)
OUT=$(python3 -I "$SBD_ROOT/lib/tailscale.py" <<<"$J")
IFS=$'\t' read -r STATE NET <<<"$(head -1 <<<"$OUT")"
ON=0; [ "$STATE" = Running ] && ON=1
sketchybar --set ts drawing=on icon.background.image="$PX_DIR/ts_$([ $ON = 1 ] && echo on || echo off).png"
[ -n "$SB_BOOT" ] && exit 0

W=336
DEVS=$(tail -n +2 <<<"$OUT")
{ if [ $ON = 1 ]; then printf 'status\tconnected\t%s\t\n' "$TEXT"; else printf 'status\toff\t%s\t\n' "$TEXT3"; fi
  n=1
  while IFS=$'\037' read -r name ip online me vnc; do   # 0x1f: a tab IFS would merge an empty ip
    [ -z "$name" ] && continue; n=$((n + 1))
    if [ "$online" = 1 ]; then
      cl=""; [ "$me" = 0 ] && cl="printf %s '$ip' | pbcopy"; [ -n "$vnc" ] && cl="open 'vnc://$vnc'"
      printf '●\t%s\t%s\t%s\n' "$name" "$TEXT" "$cl"
    else printf '○\t%s\t%s\t\n' "$name" "$TEXT3"; fi
  done < <(tr '\t' '\037' <<<"$DEVS")
  for ((; n < 9; n++)); do printf '~\t.\t\t\n'; done
  printf 'open\tadmin ↗\t%s\topen "https://login.tailscale.com/admin"\n' "$TEXT2"
} | nbsp2 | POPUP_W=$W popup_rows ts TAILSCALE

# Right column as images: tailnet on the status row, IP or "offline" on device rows.
a=(); for i in 0 1 2 3 4 5 6 7 8 9; do a+=(--set ts.p.$i icon.y_offset=$POPUP_KEY_DY background.image.drawing=off); done
for i in 2 3 4 5 6 7 8; do a+=(--set ts.p.$i label.font="$FONT_BASE"); done
[ $ON = 1 ] && a+=(--set ts.p.1 label.font="$FONT_BOLD")      # this device is bold
PX=()
[ $ON = 1 ] && [ -n "$NET" ] && popup_right ts.p.0 "$NET" "$TEXT3" $W
i=1
while IFS=$'\037' read -r name ip online me vnc; do
  [ -z "$name" ] && continue
  if [ "$online" = 1 ]; then a+=(--set ts.p.$i icon.color=$GREEN); popup_right ts.p.$i "$ip" "$TEXT2" $W
  else popup_right ts.p.$i offline "$TEXT3" $W; fi
  i=$((i + 1))
done < <(tr '\t' '\037' <<<"$DEVS")
sketchybar "${a[@]}" "${PX[@]}" 2>/dev/null
