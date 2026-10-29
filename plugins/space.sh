#!/bin/bash
# One space dot: the selected one is longer and brighter.
. "${0%/*}/../lib/env.sh"
if [ "$SELECTED" = true ]; then W=20; C=$TEXT; else W=8; C=$TEXT3; fi
sketchybar --animate $ANIM_CURVE $ANIM_FRAMES --set "$NAME" label.width=$W background.color=$C
