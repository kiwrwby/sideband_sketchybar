#!/bin/bash
# Equaliser bars: a 0.55 s loop that runs only while something plays. media.sh starts
# and stops it. The baseline is fixed: a bar of height h is raised by (h-10)/2, so its
# bottom stays on one line. Even heights only; odd ones put the baseline off by half a point.
. "${0%/*}/../lib/env.sh"
trap 'exit 0' TERM
H=("4 8 6" "8 6 10" "6 10 4" "10 6 8" "6 8 10"); k=0
while sbd_bar_alive; do
  set -- ${H[$k]}; a=()
  for i in 1 2 3; do h=${!i}; a+=(--set media.eq.$i background.height=$h background.y_offset=$(( (h - 10) / 2 ))); done
  sketchybar --animate sin 22 "${a[@]}" 2>/dev/null || exit 0
  k=$(( (k + 1) % 5 )); sleep 0.55
done
