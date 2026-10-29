#!/bin/bash
# Media island renderer. Runs on media_update (the media-control stream), every 2 s
# while playing and every 5 s otherwise, and on hover over the controls.
#   [eq] app title [«][▶][»]
# Geometry is fixed (items/media.sh), so nothing here changes the island's width.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
flag_on "$SHOW_MEDIA" || exit 0
US=$'\037'; STATE="$SBD_CACHE/media_state"

case "$SENDER" in   # hover brightens a control; nothing to press when nothing plays
  mouse.entered) [ "$(cat "$STATE" 2>/dev/null)" = none ] || sketchybar --set "$NAME" label.color=$TEXT; exit 0 ;;
  mouse.exited)  [ "$(cat "$STATE" 2>/dev/null)" = none ] || sketchybar --set "$NAME" label.color=$TEXT3; exit 0 ;;
esac

IFS=$'\t' read -r MEDIA_W MEDIA_CELL < "$SBD_CACHE/media_geometry" || exit 0
fit() { printf 'k\t%s\n' "$1" | textfit "$2" | cut -f2; }   # <text> <max pt>
# The cell is app + title. The app caption takes what it needs (at most 45%, the
# caption's own right padding included) and the title gets the rest, so the cell width,
# and with it the island, never changes.
split_cell() {   # <app text>
  local need=$(( $(textw "$1") + 8 )) cap=$(( MEDIA_CELL * 45 / 100 ))
  [ $need -gt $cap ] && need=$cap
  ICON_W=$need; APP_W=$(( need - 8 )); TITLE_W=$(( MEDIA_CELL - need ))
}

IFS=$US read -r S APP TITLE ARTIST ALBUM EL DUR SRC <<<"$("$SBD_PLUGINS/media_source.sh")"
echo "$S" > "$STATE"
mm() { [ -n "$1" ] && printf '%d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
CTL="$SBD_PLUGINS/media_ctl.sh"
LAST="$SBD_CACHE/media_last"
HAS_DUR=0; [ "${DUR:-0}" -gt 0 ] 2>/dev/null && HAS_DUR=1

# ── Nothing playing ───────────────────────────────────────────────────────────
if [ "$S" = none ]; then
  IFS=$US read -r LAPP LTITLE < "$LAST" 2>/dev/null
  split_cell "${LAPP:-media}"
  sbd_stop media_eq
  a=(--set media update_freq=5 icon="$(fit "${LAPP:-media}" $APP_W)" icon.width=$ICON_W label.width=$TITLE_W \
          icon.color=$TEXT3 label="$(fit "${LTITLE:-—}" $TITLE_W)" label.color=$TEXT3 \
          background.image.drawing=off
     --set media.play label="▶" label.y_offset=0 label.color=$([ -n "$LAPP" ] && echo $TEXT3 || echo $LINE)
     --set media.prev label.color=$LINE --set media.next label.color=$LINE)
  for i in 1 2 3; do a+=(--set media.eq.$i background.color=$LINE background.height=2 background.y_offset=-4); done
  sketchybar "${a[@]}"
  { printf 'last\t%s\t%s\t\napp\t%s\t%s\t\n' "${LTITLE:-—}" "$TEXT2" "${LAPP:-—}" "$TEXT2"
    [ -n "$LAPP" ] && printf '▶\tResume\t%s\t%s toggle\n' "$TEXT" "$CTL"
    for k in 1 2 3 4 5 6 7 8 9; do printf '~\t.\t\t\n'; done; } | head -n 9 | textfit 170 | POPUP_W=262 popup_rows media MEDIA
  for k in 0 1 2; do sketchybar --set media.p.$k background.height=$POPUP_ROW_H background.image.drawing=off background.color=$CLEAR label.drawing=on 2>/dev/null; done
  exit 0
fi

printf '%s\037%s\n' "$APP" "$TITLE" > "$LAST"
if [ "$S" = playing ]; then PL="❚❚"; PW="Pause"; CC=$TEXT2; FREQ=2
  sbd_ensure media_eq /bin/bash "$SBD_PLUGINS/media_eq.sh"
  for i in 1 2 3; do sketchybar --set media.eq.$i background.color=$ACCENT; done
else PL="▶"; PW="Play"; CC=$TEXT3; FREQ=5
  sbd_stop media_eq
  for i in 1 2 3; do sketchybar --set media.eq.$i background.color=$TEXT3 background.height=2 background.y_offset=-4; done
fi

# Progress under the title cell: only when the source reports a duration. Firefox and
# Chrome do for ordinary video; live streams do not, and then the line is hidden.
PROG=(background.image.drawing=off)
if flag_on "$MEDIA_PROGRESS" && [ $HAS_DUR = 1 ]; then
  pct=$(( ${EL:-0} * 100 / DUR )); [ $pct -gt 100 ] && pct=100
  PROG=(background.image="$SBD_CACHE/px/prog_$pct.png" background.image.drawing=on)
fi
split_cell "$APP"
sketchybar --set media icon="$(fit "$APP" $APP_W)" icon.width=$ICON_W label.width=$TITLE_W icon.color=$TEXT3 \
  label="$(fit "$TITLE" $TITLE_W)" label.color=$TEXT update_freq=$FREQ "${PROG[@]}" \
  --set media.play label="$PL" label.y_offset=$([ "$PL" = "▶" ] && echo 0 || echo 1) label.color=$CC \
  --set media.prev label.color=$CC --set media.next label.color=$CC

# ── Popup ─────────────────────────────────────────────────────────────────────
# art cell · title · artist · album · time · gauge · prev · play · next · open
OPEN="open -a '$APP'"; [ "$SRC" = music ] && OPEN="open -a Music"
ART=$(cat "$SBD_CACHE/art.path" 2>/dev/null); [ -s "$ART" ] || ART=""
{ printf '_\t.\t\t\n_\t%s\t%s\t\n_\t%s\t%s\t\n' "$TITLE" "$TEXT" "${ARTIST:-—}" "$TEXT2"
  if [ -n "$ALBUM" ]; then printf '_\t%s\t%s\t\n' "$ALBUM" "$TEXT3"; else printf '~\t.\t\t\n'; fi
  if [ $HAS_DUR = 1 ]; then printf '_\t.\t\t\n_\t.\t\t\n'; else printf '~\t.\t\t\n~\t.\t\t\n'; fi
  printf '«\tPrevious\t%s\t@%s prev\n%s\t%s\t%s\t@%s toggle\n»\tNext\t%s\t@%s next\nopen\t%s ↗\t%s\t%s\n' \
    "$TEXT" "$CTL" "$PL" "$PW" "$TEXT" "$CTL" "$TEXT" "$CTL" "$APP" "$TEXT2" "$OPEN"
} | textfit 230 | POPUP_W=262 popup_rows media MEDIA
# rows: 0 art, 1 title, 2 artist, 3 album, 4 time, 5 gauge, 6 prev, 7 play, 8 next, 9 open

PX=()
a=()
if [ -n "$ART" ]; then
  PH=$(sips -g pixelHeight "$ART" 2>/dev/null | awk '/pixelHeight/{print $2}'); SC=$(awk -v h="${PH:-238}" 'BEGIN{printf "%.4f", 238/h}')
  a+=(--set media.p.0 drawing=on background.drawing=on background.color=$CLEAR background.height=238 background.image="$ART"
      background.image.drawing=on background.image.scale=$SC label.drawing=off icon.drawing=off width=238 padding_left=12 padding_right=12)
else
  a+=(--set media.p.0 drawing=off)    # no art from this source: no empty frame
fi
if [ $HAS_DUR = 1 ]; then
  popup_right media.p.4 "$(mm "$DUR")" "$TEXT3" 262
  pct=$(( ${EL:-0} * 100 / DUR )); [ $pct -gt 100 ] && pct=100
  a+=(--set media.p.4 label="" icon.drawing=on icon="$(mm "${EL:-0}")" icon.color=$TEXT2 icon.width=dynamic icon.padding_left=$POPUP_PAD
      --set media.p.5 label.drawing=off icon.drawing=off height=8 background.drawing=on background.color=$CLEAR background.height=8
      background.image="$SBD_CACHE/px/pop_$pct.png" background.image.scale=0.5 background.image.drawing=on
      background.image.padding_left=$POPUP_PAD background.image.y_offset=0)
fi
# Captions of icon rows sit 1pt high; the glyph rows are corrected here.
PY=-1; PX0=13; [ "$PL" = "❚❚" ] && { PY=0; PX0=11; }
a+=(--set media.p.6 icon.y_offset=0 icon.padding_left=12 label.y_offset=-1
    --set media.p.7 icon.y_offset=$PY icon.padding_left=$PX0 label.y_offset=-1
    --set media.p.8 icon.y_offset=0 icon.padding_left=12 label.y_offset=-1
    --set media.p.9 icon.y_offset=$POPUP_KEY_DY icon.padding_left=12)
sketchybar "${a[@]}" "${PX[@]}" 2>/dev/null
