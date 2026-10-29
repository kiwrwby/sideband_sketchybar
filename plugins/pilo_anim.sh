#!/bin/bash
# Pilo face motion: cycles the frames of the current state. Urgent states move fast
# (0.35-0.45 s), the rest slowly, "unbound" is a single frame. While the popup is open
# the small faces on its rows move too, driven by one 0.15 s tick. Exits when the state
# file says off. pilo.sh starts it. Reduce Motion and PILO_ANIMATE=0 keep frame 1.
. "${0%/*}/../lib/env.sh"
PXD="$SBD_CACHE/px"; trap 'exit 0' TERM
# F frames · T period (s) · P popup ticks (0.15 s x P is about T)
spec() { case "$1" in running) F=4 T=0.45 P=3 ;; blocked) F=2 T=0.4 P=3 ;; failed) F=2 T=0.35 P=2 ;; gaveUp) F=2 T=1.2 P=8 ;; stalled) F=2 T=1.6 P=11 ;; limited) F=2 T=1.2 P=8 ;; idle) F=2 T=2 P=13 ;; *) F=1 T=3 P=20 ;; esac; }
k=1; last=""; t=0
while sbd_bar_alive; do
  read -r S < "$SBD_CACHE/pilo" 2>/dev/null; { [ "$S" = off ] || [ -z "$S" ]; } && exit 0
  O=""; read -r O < "$SBD_CACHE/popup_open" 2>/dev/null
  if [ "$O" = pilo.ul ]; then
    t=$((t + 1)); a=(); i=0
    spec "$S"; [ $F -gt 1 ] && [ $(( t % P )) = 0 ] && a+=(--set pilo background.image="$PXD/pilo_${S}_$(( t / P % F + 1 )).png")
    while read -r R; do
      spec "$R"; [ $F -gt 1 ] && [ $(( t % P )) = 0 ] && a+=(--set pilo.ul.p.$i background.image="$PXD/pilo_s_${R}_$(( t / P % F + 1 )).png")
      i=$((i + 1))
    done < "$SBD_CACHE/pilo_rows" 2>/dev/null
    [ ${#a[@]} -gt 0 ] && sketchybar "${a[@]}" 2>/dev/null
    last=""; sleep 0.15; continue
  fi
  spec "$S"; [ $F = 1 ] && { sleep 3; continue; }
  [ "$S" = "$last" ] || { k=1; last=$S; }
  k=$(( k % F + 1 ))
  sketchybar --set pilo background.image="$PXD/pilo_${S}_$k.png" 2>/dev/null
  sleep $T
done
