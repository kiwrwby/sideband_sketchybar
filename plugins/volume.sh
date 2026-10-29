#!/bin/bash
# Volume: glyph and 5-cell gauge at the right end of the media island, popup with a
# slider, mute and output devices.
# Value: osascript. Devices: helpers/bin/audio (CoreAudio plus paired Bluetooth), the
# same list as Control Center's Sound output.
# Refresh: volume_change (keys, slider) updates bar and slider only; every 10 s because
# device changes have no event; after wake; and the audio watcher for mute and device switches.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
flag_on "$SHOW_MEDIA" || exit 0
AUDIO="$SBD_HELPERS/audio"; ST="$SBD_CACHE/vol_state"
G_LO=$'\xf3\xb0\x95\xbf' G_MID=$'\xf3\xb0\x96\x80' G_HI=$'\xf3\xb0\x95\xbe' G_MUTE=$'\xf3\xb0\x96\x81'
G_BT=$'\xf3\xb0\xa5\xb0' G_BTMUTE=$'\xf3\xb0\x9f\x8e' G_LAPTOP=$'\xf3\xb0\x8c\xa2'

bar() {   # glyph (speaker levels, headphones for Bluetooth, slashed when muted) + 5 cells (20% each) + slider
  local g gc=$TEXT2 n i a lt="$V%" lc=$TEXT hc=$TEXT lw
  if [ "$KIND" = bluetooth ]; then g=$G_BT; [ "$M" = true ] && g=$G_BTMUTE
  elif [ "$M" = true ]; then g=$G_MUTE; elif [ "$V" -le 33 ]; then g=$G_LO; elif [ "$V" -le 66 ]; then g=$G_MID; else g=$G_HI; fi
  [ "$M" = true ] && { gc=$TEXT3; lt=off; lc=$TEXT3; hc=$TEXT3; }
  n=$(( (V + 19) / 20 )); a=(--set vol icon="$g" icon.color=$gc)
  for i in 1 2 3 4 5; do a+=(--set vol.$i background.color=$([ $i -le $n ] && echo $TEXT || echo $LINE)); done
  lw=$(textw "$lt")
  # A slider ignores label.width: pad the front so the % ends at the right padding.
  [ -n "$(sketchybar --query vol.slider 2>/dev/null)" ] && \
    a+=(--set vol.slider slider.percentage=$V slider.highlight_color=$hc label="$lt" label.color=$lc label.padding_left=$(( 53 - lw )))
  sketchybar "${a[@]}"
}

# Volume only: bar and slider, immediately. Mute and device come from the last full read.
if [ "$SENDER" = volume_change ] && [[ "$INFO" =~ ^[0-9]+$ ]]; then
  V=$INFO; IFS=$'\t' read -r M KIND < "$ST" 2>/dev/null; bar; exit 0
fi

IFS=, read -r V M <<<"$(osascript -e 'set s to get volume settings' -e 'return (output volume of s as text) & "," & (output muted of s as text)' 2>/dev/null)"
V=${V:-0}; DEV=$("$AUDIO" 2>/dev/null)
KIND=$(awk -F'\t' '$4==1{print $3}' <<<"$DEV"); printf '%s\t%s\n' "$M" "$KIND" > "$ST"
[ -n "$SB_BOOT" ] && { bar; exit 0; }

# Paired but disconnected Bluetooth devices take about 4 s to list: cache for 30 s.
BTF="$SBD_CACHE/vol_bt"
[ -n "$(find "$BTF" -mtime -30s 2>/dev/null)" ] || { "$AUDIO" bt > "$BTF.tmp" 2>/dev/null; mv "$BTF.tmp" "$BTF"; }
BT=$(cat "$BTF" 2>/dev/null)

# Popup rows are created here once, in order: pads, title, slider, 9 rows, pad.
# --move does not work on popup items, so creation order puts the slider under the title.
if [ -z "$(sketchybar --query vol.slider 2>/dev/null)" ]; then
  r=(); for it in $(sketchybar --query vol.ul 2>/dev/null | jq -r '.popup.items[]?'); do r+=(--remove "$it"); done
  [ ${#r[@]} -gt 0 ] && sketchybar "${r[@]}" >/dev/null 2>&1
  a=(--add item vol.ul.p.a popup.vol.ul --add item vol.ul.p.t popup.vol.ul --add item vol.ul.p.g popup.vol.ul
     --add slider vol.slider popup.vol.ul 132
     --set vol.slider icon=vol icon.font="$FONT_BASE" icon.color=$TEXT3 icon.width=$POPUP_KEY_W icon.padding_left=$POPUP_PAD icon.padding_right=0 \
           label.font="$FONT_BASE" label.color=$TEXT label.padding_right=$POPUP_PAD \
           slider.highlight_color=$TEXT slider.background.color=$LINE slider.background.height=10 slider.background.corner_radius=0 \
           slider.background.y_offset=-1 slider.knob.drawing=off background.drawing=on background.color=$CLEAR \
           background.height=$POPUP_ROW_H script="$SBD_PLUGINS/volume_slider.sh"
     --subscribe vol.slider mouse.clicked)
  for i in 0 1 2 3 4 5 6 7 8; do a+=(--add item vol.ul.p.$i popup.vol.ul); done
  sketchybar "${a[@]}" --add item vol.ul.p.z popup.vol.ul
  echo 9 > "$SBD_CACHE/popup.vol.ul.n"; rm -f "$SBD_CACHE/popup.vol.ul"
fi
bar

# Rows: mute, OUTPUT header, up to 6 devices (padded), settings. The joined device
# gets a check mark at the right edge (a text image: spaces move it in 7.2pt steps).
W=$POPUP_W_DEFAULT
SAY="@/bin/bash $SBD_PLUGINS/volume_out.sh"
MUTE_CMD="@osascript -e \"set volume output muted (not output muted of (get volume settings))\"; SENDER=routine /bin/bash \"$SBD_PLUGINS/volume.sh\""
{ printf '%s\t%s\t%s\t%s\n' "$G_MUTE" "$([ "$M" = true ] && echo 'Unmute ' || echo 'Mute ')" "$TEXT" "$MUTE_CMD"
  printf '_\tOUTPUT\t%s\t\n' "$TEXT3"
  k=0
  while IFS=$'\t' read -r id name kind cur; do
    [ -z "$id" ] && continue; k=$((k + 1)); [ $k -gt 6 ] && break
    case "$kind" in builtin) g=$G_LAPTOP ;; bluetooth) g=$G_BT ;; *) g=$G_HI ;; esac
    if [ "$cur" = 1 ]; then printf '%s\t%s\t%s\t\n' "$g" "$name" "$TEXT"
    else printf '%s\t%s\t%s\t%s set %s %s\n' "$g" "$name" "$TEXT2" "$SAY" "$id" "$k"; fi
  done <<<"$DEV"
  while IFS=$'\t' read -r addr name; do
    [ -z "$addr" ] && continue; k=$((k + 1)); [ $k -gt 6 ] && break
    printf '%s\t%s\t%s\t%s connect %s %s\n' "$G_BT" "$name" "$TEXT2" "$SAY" "$addr" "$k"   # paired only: click connects, then switches
  done <<<"$BT"
  for ((; k < 6; k++)); do printf '~\t.\t\t\n'; done
  printf 'open\tSound Settings ↗\t%s\topen "x-apple.systempreferences:com.apple.Sound-Settings.extension"\n' "$TEXT2"
} | nbsp2 | POPUP_PREBUILT=1 POPUP_W=$W popup_rows vol.ul VOLUME

a=(--set vol.ul.p.8 icon.y_offset=$POPUP_KEY_DY --set vol.ul.p.0 icon.padding_left=13 icon.font="$FONT_ICON"
   icon.color=$([ "$M" = true ] && echo $TEXT || echo $TEXT3) --set vol.ul.p.1 label.font="$FONT_SMALL")
CUR=$(awk -F'\t' '$4==1{print NR}' <<<"$DEV")   # row of the joined device, from 1
KINDS=($( { awk -F'\t' '$1!=""{print $3}' <<<"$DEV"; awk -F'\t' '$1!=""{print "bluetooth"}' <<<"$BT"; } | head -6))
for i in 2 3 4 5 6 7; do
  k=${KINDS[$((i - 2))]}; fs=14.0; [ "$k" = bluetooth ] && fs=17.0   # the Bluetooth glyph is drawn smaller in the font
  a+=(--set vol.ul.p.$i icon.padding_left=13 icon.font="$ICON_FONT:Regular:$fs" icon.y_offset=0 background.image.drawing=off \
        icon.color=$([ "$i" = "$(( ${CUR:-0} + 1 ))" ] && echo $TEXT || echo $TEXT3))
done
PX=(); [ -n "$CUR" ] && popup_right "vol.ul.p.$(( CUR + 1 ))" "✓" "$TEXT" "$W"
sketchybar "${a[@]}" "${PX[@]}" 2>/dev/null
