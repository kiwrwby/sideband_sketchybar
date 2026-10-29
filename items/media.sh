#!/bin/bash
# Media island, right behind the left island. Built only when SHOW_MEDIA=1.
#   [eq] app title [«][▶][»] | volume glyph + 5-cell gauge
# The island has a fixed width. The title cell takes what is left, so track and app
# changes never move or resize it. It follows the left island, so its position changes
# when that island grows or shrinks, and its size does not.

if ! flag_on "$SHOW_MEDIA"; then
  sbd_stop media_watch; sbd_stop media_eq; sbd_stop audio_watch
  return 0 2>/dev/null || true
fi

NOTCH_L=$(cat "$SBD_CACHE/notch_l")
# Room: from the end of the left island, estimated at its widest, to the notch.
# 5 margin + 30 button, wordmark label + padding, space dots (up to ~10), app name at
# FRONT_APP_MAX characters, paddings.
LEFT_EST=$(( 5 + 30 + WM_W + ISLAND_PAD + 2 + 12 + 140 + 6 + 12 + $(textw "$(printf '%*s' "$FRONT_APP_MAX" '' | tr ' ' 0)") + ISLAND_PAD ))
flag_on "$SHOW_CWD" && LEFT_EST=$(( LEFT_EST + 12 + $(textw "$(printf '%*s' "$CWD_MAX" '' | tr ' ' 0)") ))
flag_on "$SHOW_GIT" && LEFT_EST=$(( LEFT_EST + 12 + $(textw git) + 8 + $(textw "$(printf '%*s' "$GIT_BRANCH_MAX" '' | tr ' ' 0)") + 12 ))
if [ "${MEDIA_WIDTH:-auto}" = auto ]; then
  MEDIA_W=$(( NOTCH_L - LEFT_EST - ISLAND_GAP ))
  [ $MEDIA_W -gt 380 ] && MEDIA_W=380
  [ $MEDIA_W -lt 280 ] && MEDIA_W=280
else
  MEDIA_W=$MEDIA_WIDTH
fi
# Fixed parts: left pad, three equaliser bars with their gaps (18), the three controls
# (38 + 26 + 24), divider, volume glyph (34), gauge (28), right pad.
MEDIA_FIXED=$(( ISLAND_PAD + 18 + 88 + 1 + 34 + 28 + ISLAND_PAD ))
MEDIA_CELL=$(( MEDIA_W - MEDIA_FIXED ))        # app + title cell, constant
printf '%s\t%s\n' "$MEDIA_W" "$MEDIA_CELL" > "$SBD_CACHE/media_geometry"
python3 "$SBD_ROOT/lib/pixel.py" progress "$SBD_CACHE/px" "$MEDIA_CELL" "$ACCENT" "$LINE" prog 2>/dev/null
python3 "$SBD_ROOT/lib/pixel.py" progress "$SBD_CACHE/px" 238 "$ACCENT" "$LINE" pop 2>/dev/null

CTL="icon.drawing=off label.width=14 label.align=center label.color=$TEXT3 label.y_offset=1"
# Left to right, right behind the left island: the media island follows it, whatever its
# width, instead of sitting against the notch. The two overlays at the end (hit area of the
# gauge, popup anchor) step back over what precedes them with a negative padding_left. That
# moves what is drawn, not the cursor, so they must stay last: anything after them
# would be pushed right. A negative padding_right does nothing in this flow.
sb --add item media.gap left --set media.gap width=$ISLAND_GAP icon.drawing=off label.drawing=off
for i in 1 2 3; do
  pl=0; pr=2; [ $i = 3 ] && pr=8; [ $i = 1 ] && pl=$ISLAND_PAD
  sb --add item media.eq.$i left --set media.eq.$i icon.drawing=off label="" label.width=2 padding_left=$pl padding_right=$pr \
        background.drawing=on background.color=$LINE background.height=2 background.y_offset=-4
done
sb --add item media left \
   --set media icon=media icon.padding_right=8 icon.color=$TEXT3 icon.width=$(( MEDIA_CELL / 3 )) icon.align=left label="—" label.color=$TEXT3 \
         label.align=left label.width=$(( MEDIA_CELL - MEDIA_CELL / 3 )) padding_right=0 update_freq=2 popup.align=left \
         script="$P/media.sh" click_script="$P/popup_click.sh media" \
         background.drawing=on background.color=$CLEAR background.height=$ISLAND_HEIGHT \
         background.image.drawing=off background.image.scale=0.5 background.image.y_offset=$(( 3 - ISLAND_HEIGHT / 2 )) \
   --subscribe media media_update

ctl() {   # <name> <glyph> <label width> <action> <extra>
  sb --add item "media.$1" left \
     --set "media.$1" label="$2" $CTL label.width=$3 padding_right=0 $5 \
           click_script="$P/media_ctl.sh $4" script="$P/media.sh" \
     --subscribe "media.$1" mouse.entered mouse.exited
}
ctl prev "«" 38 prev "label.padding_left=12 label.padding_right=12"
ctl play "▶" 26 toggle "label.padding_right=12"
ctl next "»" 24 next "label.padding_right=10"

sb --add item vol.sep left --set vol.sep icon.drawing=off label="" label.width=1 padding_left=0 padding_right=0 \
      background.drawing=on background.color=$TEXT3 background.height=12 click_script="$P/popup_click.sh vol.ul"
sb --add item vol left \
   --set vol icon=$'\xf3\xb0\x95\xbe' icon.font="$FONT_ICON_LARGE" icon.color=$TEXT2 icon.width=34 icon.align=center \
         icon.padding_right=0 label.drawing=off padding_right=0 update_freq=10 script="$P/volume.sh" \
         click_script="$P/popup_click.sh vol.ul" \
   --subscribe vol volume_change system_woke
for c in 1 2 3 4 5; do
  gap=2; [ $c = 5 ] && gap=0
  sb --add item vol.$c left --set vol.$c icon.drawing=off label="" label.width=4 background.height=10 \
        background.color=$LINE background.drawing=on padding_right=$gap click_script="$P/popup_click.sh vol.ul"
done
# 39 wide, 28 back over the gauge: the hit area of the gauge and the island's right padding.
sb --add item vol.pad left --set vol.pad padding_left=-28 padding_right=0 icon.drawing=off label="" label.width=39 \
      background.drawing=on background.color=$CLEAR background.height=$ISLAND_HEIGHT \
      click_script="$P/popup_click.sh vol.ul"
# Popup anchor and underline of the gauge. Net width zero.
sb --add item vol.ul left --set vol.ul padding_left=-60 padding_right=$ISLAND_PAD icon.drawing=off label="" label.width=49 \
      popup.align=right click_script="$P/popup_click.sh vol.ul"
