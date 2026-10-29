#!/bin/bash
# Reload once when the macOS appearance changes, only with THEME=auto.
. "${0%/*}/../lib/env.sh"
[ "$SENDER" = theme_change ] && [ "$THEME" = auto ] || exit 0
now=$(defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark && echo dark || echo light)
[ "$now" = "$(cat "$SBD_CACHE/appearance" 2>/dev/null)" ] && exit 0   # duplicate notification
echo "$now" > "$SBD_CACHE/appearance"
sketchybar --reload
