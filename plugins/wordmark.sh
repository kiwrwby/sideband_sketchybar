#!/bin/bash
# Typewriter wordmark.
#   wordmark.sh        run the animation (started by rc, restart-safe)
#   wordmark.sh skip   jump to the next phrase (click on the wordmark)
#
# The label has a fixed width (items/left.sh), so every frame is one sketchybar call
# that changes text only: no layout change, no clipping.
. "${0%/*}/../lib/env.sh"
if [ "$1" = skip ]; then : > "$SBD_CACHE/wordmark.skip"; exit 0; fi
trap 'exit 0' TERM

s() { awk -v ms="$1" 'BEGIN { printf "%.3f", ms / 1000 }'; }
T_TYPE=$(s "$WORDMARK_TYPE_MS"); T_ERASE=$(s "$WORDMARK_ERASE_MS"); T_PAUSE=$(s "$WORDMARK_PAUSE_MS")
T_BLINK=0; [ "${WORDMARK_BLINK_MS:-0}" -gt 0 ] && T_BLINK=$(s "$WORDMARK_BLINK_MS")
BLINKS=0; [ "$T_BLINK" != 0 ] && BLINKS=$(( WORDMARK_HOLD_S * 1000 / WORDMARK_BLINK_MS ))
CUR="_"; flag_on "$WORDMARK_CURSOR" || CUR=""
[ ${#WORDMARK_PHRASES[@]} -gt 0 ] || exit 0

frame() { sketchybar --set wordmark label="$1" 2>/dev/null || exit 0; }   # SketchyBar gone: leave

while sbd_bar_alive; do
  for text in "${WORDMARK_PHRASES[@]}"; do
    rm -f "$SBD_CACHE/wordmark.skip"
    n=${#text}
    k=1; while [ $k -le $n ]; do frame "${text:0:k}$CUR"; sleep "$T_TYPE"; k=$((k + 1)); done
    # Hold with a blinking cursor. A click on the wordmark ends the hold early.
    if [ "$BLINKS" -gt 0 ] && [ -n "$CUR" ]; then
      b=0; on=1
      while [ $b -lt $BLINKS ] && [ ! -e "$SBD_CACHE/wordmark.skip" ]; do
        sleep "$T_BLINK"; b=$((b + 1)); sbd_bar_alive || exit 0
        if [ $on = 1 ]; then frame "$text "; on=0; else frame "$text$CUR"; on=1; fi
      done
    else
      h=0; while [ $h -lt "$WORDMARK_HOLD_S" ] && [ ! -e "$SBD_CACHE/wordmark.skip" ]; do sleep 1; h=$((h + 1)); done
    fi
    k=$((n - 1)); while [ $k -ge 0 ]; do frame "${text:0:k}$CUR"; sleep "$T_ERASE"; k=$((k - 1)); done
    sleep "$T_PAUSE"
  done
done
