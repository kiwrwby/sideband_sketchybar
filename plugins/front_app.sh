#!/bin/bash
# Active application name. The width animates over ANIM_FRAMES.
. "${0%/*}/../lib/env.sh"
case "$SENDER" in   # hover brightens the name
  mouse.entered) sketchybar --set "$NAME" label.color=$TEXT; exit 0 ;;
  mouse.exited)  sketchybar --set "$NAME" label.color=$TEXT2; exit 0 ;;
esac
[ "$SENDER" = front_app_switched ] || exit 0
n=$(printf '%s' "$INFO" | tr '[:upper:]' '[:lower:]')
# Keep the island bounded: the media island is sized for at most FRONT_APP_MAX cells.
max=$FRONT_APP_MAX
[ "${#n}" -gt "$max" ] && n="${n:0:$((max - 1))}…"
FA="$SBD_CACHE/front_app.last"
old=$(cat "$FA" 2>/dev/null)
[ -n "$old" ] || old=$(sketchybar --query "$NAME" 2>/dev/null | jq -r '.label.value' 2>/dev/null)
wn=$(textw "$n")
if [ -n "$SB_BOOT" ]; then
  sketchybar --set "$NAME" label="$n" label.width=$wn; echo "$n" > "$FA"; exit 0
fi
wo=$(textw "$old")
sketchybar --set "$NAME" label="$n" label.width=$wo --animate $ANIM_CURVE $ANIM_FRAMES --set "$NAME" label.width=$wn
echo "$n" > "$FA"
