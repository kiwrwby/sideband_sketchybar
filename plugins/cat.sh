#!/bin/bash
# Pixel cat animation. Frame rate follows CPU: 0.6 s per frame idle down to 0.12 s at
# 80%. Memory at 80% or more switches to the warning art. system.sh writes the numbers.
. "${0%/*}/../lib/env.sh"
PX="$SBD_CACHE/px"
trap 'exit 0' TERM
k=1
while sbd_bar_alive; do
  read -r CPU MEM < "$SBD_CACHE/cat" 2>/dev/null; CPU=${CPU:-0}; MEM=${MEM:-0}
  w=""; [ "$MEM" -ge 80 ] && w=_warn
  sketchybar --set cpu background.image="$PX/cat_$k$w.png" 2>/dev/null || exit 0
  k=$(( k % 4 + 1 ))
  if [ "$CPU" -ge 80 ]; then sleep 0.12; else sleep "$(awk -v c="$CPU" 'BEGIN{printf "%.2f", 0.6 - c * 0.006}')"; fi
done
