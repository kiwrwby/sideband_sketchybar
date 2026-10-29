#!/bin/bash
# Playback controls. Click handlers of « ▶ » and the popup rows call this.
#   media_ctl.sh prev | toggle | next
# Sends the command through media-control (any app) or AppleScript (Apple Music
# only), then waits up to 1 s for the state to actually change before refreshing, so
# a slow app never leaves a stale glyph. Every click is logged to media.log.
. "${0%/*}/../lib/env.sh"
LOG="$SBD_CACHE/media.log"
case "${1:-}" in
  prev) CMD=previous-track; MAC="previous track" ;;
  next) CMD=next-track;     MAC="next track" ;;
  toggle) CMD=toggle-play-pause; MAC=playpause ;;
  *) echo "usage: media_ctl.sh prev|toggle|next" >&2; exit 2 ;;
esac
[ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt 200 ] && tail -100 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

# Ignore a second click within 0.3 s: toggling twice looks like nothing happened.
LAST=$(cat "$SBD_CACHE/media_click" 2>/dev/null || echo 0); NOW=$(perl -MTime::HiRes=time -e 'printf "%d", time*1000')
[ $(( NOW - LAST )) -lt 300 ] && exit 0
echo "$NOW" > "$SBD_CACHE/media_click"

US=$'\037'
before=$("$SBD_PLUGINS/media_source.sh" | cut -d"$US" -f1,3)
SRC=$("$SBD_PLUGINS/media_source.sh" | cut -d"$US" -f8)
MC=$(find_cli media-control)
if [ -n "$MC" ] && [ "$SRC" != music ]; then
  with_timeout 5 "$MC" "$CMD" >/dev/null 2>&1; rc=$?
elif [ "$SRC" = music ] || [ "$(osascript -e 'application "Music" is running' 2>/dev/null)" = true ]; then
  with_timeout 5 osascript -e "tell application \"Music\" to $MAC" >/dev/null 2>&1; rc=$?
else
  rc=127
fi
printf '%s  %-6s src=%s rc=%s\n' "$(date '+%F %T')" "$1" "${SRC:-none}" "$rc" >> "$LOG"
[ $rc = 0 ] || exit $rc

# Position moves on its own, so compare state (toggle) or title (prev, next).
for _ in 1 2 3 4 5; do
  sleep 0.2
  now=$("$SBD_PLUGINS/media_source.sh" | cut -d"$US" -f1,3)
  [ "$1" = toggle ] && [ "${now%%$US*}" != "${before%%$US*}" ] && break
  [ "$1" != toggle ] && [ "${now#*$US}" != "${before#*$US}" ] && break
done
sketchybar --trigger media_update
