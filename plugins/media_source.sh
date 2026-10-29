#!/bin/bash
# Now-playing on one line:
#   state US app US title US artist US album US elapsed s US duration s US source
# US is the unit separator, 0x1f. A tab would let `read` swallow empty fields.
# state = playing | paused | none. duration is empty when the source does not report one.
# source = mc (media-control: every app including browsers) | music (Apple Music).
# Since macOS 15.4 ordinary programs cannot read Now Playing, so media-control (brew)
# is the primary source; Apple Music alone works without it through AppleScript.
. "${0%/*}/../lib/env.sh"
[ -f "$SBD_CACHE/media_fake" ] && { cat "$SBD_CACHE/media_fake"; exit 0; }   # tests

MC=$(find_cli media-control)
if [ -n "$MC" ]; then
  J=$("$MC" get 2>/dev/null)
  if [ -n "$J" ] && [ "$J" != null ]; then
    # elapsedTime is the position at `timestamp`: add the time since while playing.
    IFS=$'\037' read -r PLAYING BUNDLE TITLE ARTIST ALBUM ELAPSED DURATION <<<"$(jq -r '
      [ (.playing | tostring), (.bundleIdentifier // ""), (.title // ""), (.artist // ""), (.album // ""),
        ( ((.elapsedTime // 0) + (if .playing then ((now - ((.timestamp // "") | try fromdate catch now)) * (.playbackRate // 1)) else 0 end))
          | if . < 0 then 0 else floor end ),
        ( if (.duration // 0) > 0 then (.duration | floor) else "" end ) ] | map(tostring) | join("\u001f")' <<<"$J" 2>/dev/null)"
    if [ -n "$BUNDLE$TITLE" ]; then
      NAMEF="$SBD_CACHE/appname.$BUNDLE"
      if [ ! -s "$NAMEF" ]; then
        a=$(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE'" 2>/dev/null | head -1); a=${a##*/}; a=${a%.app}
        printf '%s' "${a:-$BUNDLE}" | tr '[:upper:]' '[:lower:]' > "$NAMEF"
      fi
      [ -n "$DURATION" ] && [ "$ELAPSED" -gt "$DURATION" ] && ELAPSED=$DURATION
      S=paused; [ "$PLAYING" = true ] && S=playing
      # Album art, when the source ships it. New file name per track: SketchyBar caches by path.
      ART=$(jq -r '.artworkData // empty' <<<"$J" 2>/dev/null)
      KEY=$(printf '%s|%s' "$TITLE" "$ARTIST" | md5 | cut -c1-12)
      if [ -n "$ART" ] && [ "$(cat "$SBD_CACHE/art.key" 2>/dev/null)" != "$KEY" ]; then
        A="$SBD_CACHE/art-$KEY.jpg"; RAW="$A.raw"
        if printf '%s' "$ART" | base64 -D > "$RAW" 2>/dev/null && "$SBD_HELPERS/artfit" "$RAW" "$A" 476 2>/dev/null; then
          rm -f "$RAW"; for f in "$SBD_CACHE"/art-*.jpg; do [ "$f" = "$A" ] || rm -f "$f"; done
          printf '%s' "$A" > "$SBD_CACHE/art.path"; printf '%s' "$KEY" > "$SBD_CACHE/art.key"
        else rm -f "$RAW" "$A"; fi
      elif [ -z "$ART" ] && [ "$(cat "$SBD_CACHE/art.key" 2>/dev/null)" != "$KEY" ]; then
        rm -f "$SBD_CACHE"/art-*.jpg "$SBD_CACHE/art.path"; printf '%s' "$KEY" > "$SBD_CACHE/art.key"
      fi
      printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\037mc\n' "$S" "$(cat "$NAMEF")" "$TITLE" "$ARTIST" "$ALBUM" "$ELAPSED" "$DURATION"
      exit 0
    fi
  fi
fi

if [ "$(osascript -e 'application "Music" is running' 2>/dev/null)" = true ]; then
  osascript <<'AS' 2>/dev/null && exit 0
tell application "Music"
  if player state is stopped then error "none"
  set s to "paused"
  if player state is playing then set s to "playing"
  set u to ASCII character 31
  return s & u & "music" & u & (name of current track) & u & (artist of current track) & u & (album of current track) & u & ((player position as integer) as text) & u & ((duration of current track as integer) as text) & u & "music"
end tell
AS
fi
printf 'none\037\037\037\037\037\037\037\n'
