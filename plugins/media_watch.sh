#!/bin/bash
# Turns the media-control stream into media_update events. The 2 s/5 s poll in
# media.sh is only a backstop. A track change arrives as several diffs within a second,
# so one event goes out after the stream goes quiet. Restarts the stream if it dies.
#
# The stream can stay silent for hours, so the reader wakes every 5 s to check that the
# SketchyBar server is still there. Without that, a daemon of a dead bar would sit in
# read() until some app happened to play something.
. "${0%/*}/../lib/env.sh"
MC=$(find_cli media-control) || exit 0
trap 'pkill -P $$ 2>/dev/null; exit 0' TERM
while sbd_bar_alive; do
  "$MC" stream 2>/dev/null | while :; do
    t0=$SECONDS; IFS= read -r -t 5 _
    if [ $? != 0 ]; then
      # bash 3.2 returns 1 for both a timeout and end of input, so tell them apart by time
      [ $(( SECONDS - t0 )) -ge 4 ] || break   # ended early: the stream died
      sbd_bar_alive || { pkill -P $$ 2>/dev/null; exit 0; }   # timeout: nothing happened, check the bar
      continue
    fi
    n=0; while [ $n -lt 5 ] && IFS= read -r -t 1 _; do n=$((n + 1)); done   # bash 3.2 reads whole seconds only
    sketchybar --trigger media_update || exit 0
  done
  sleep 2
done
