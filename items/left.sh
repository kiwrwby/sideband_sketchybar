#!/bin/bash
# Left island: [control centre] [wordmark] [spaces] [app] [git] [next event]

# ── Control Center ────────────────────────────────────────────────────────────
if flag_on "$SHOW_CONTROL_CENTER"; then
  sb --add item ctrlcenter left \
     --set ctrlcenter icon=$'\xef\xa3\xbf' icon.font="Helvetica Neue:Regular:16.0" icon.width=29 icon.align=center \
           icon.padding_left=2 icon.padding_right=2 icon.y_offset=0 $BUTTON \
           click_script="$SBD_HELPERS/open-control-center"
fi

# ── Wordmark ──────────────────────────────────────────────────────────────────
# One label of fixed width: left padding, the longest phrase and one cell for the
# cursor. label.width includes label.padding_left, so forgetting the padding clips the
# last characters. Typing
# only changes the text, so the island never moves and nothing clips. The cursor is
# an underscore in the label itself; blinking swaps it for a space.
WM_STATIC=0
{ [ "${WORDMARK_ANIMATE:-1}" != 1 ] || sbd_reduce_motion; } && WM_STATIC=1
WM_CUR=""; [ $WM_STATIC = 0 ] && flag_on "$WORDMARK_CURSOR" && WM_CUR="_"
# Widest the label can get: the longest phrase with its cursor. Measured, not counted,
# so a proportional font works as well as a monospaced one.
WM_W=$(textw "$WORDMARK$WM_CUR")
if [ $WM_STATIC = 0 ]; then
  for phrase in "${WORDMARK_PHRASES[@]}"; do
    w=$(textw "$phrase$WM_CUR"); [ "$w" -gt "$WM_W" ] && WM_W=$w
  done
fi

sb --add item wordmark left \
   --set wordmark icon.drawing=off label="$WORDMARK" label.width=$(( WM_W + ISLAND_PAD + 2 )) label.align=left \
         label.padding_left=$ISLAND_PAD label.padding_right=0 \
         click_script="/bin/bash $P/wordmark.sh skip"

# ── Spaces ────────────────────────────────────────────────────────────────────
spacer space.padl left 12
sb --add item space.padr left --set space.padr width=6 icon.drawing=off label.drawing=off
if flag_on "$SHOW_SPACES"; then
  sb --add item spaces left --set spaces drawing=off updates=on update_freq=5 script="$P/spaces.sh" \
     --subscribe spaces space_change display_change
fi

# ── Active application ────────────────────────────────────────────────────────
# app.padl keeps the cell's left padding outside the item, so the menu popup and its
# underline start at the text.
spacer app.padl left 12
sb --add item front_app left \
   --set front_app icon.drawing=off label.color=$TEXT2 padding_left=0 padding_right=$ISLAND_PAD \
         script="$P/front_app.sh" popup.align=left \
         click_script="$P/appmenu.sh open" \
   --subscribe front_app front_app_switched mouse.entered mouse.exited
flag_on "$SHOW_FRONT_APP" || sb --set front_app drawing=off --set app.padl drawing=off

# ── Git and next event ────────────────────────────────────────────────────────
# Both stay hidden until the shell hook reports a directory (plugins/git.sh).
sb --add item cwd left --set cwd drawing=off updates=on icon.drawing=off label.color=$TEXT3 \
      label.padding_left=12 label.padding_right=0 script="$P/git.sh" --subscribe cwd shell_cwd \
   --add item git left --set git drawing=off icon=git icon.color=$TEXT3 icon.padding_left=12 icon.padding_right=8 \
      label.color=$TEXT2 label.padding_right=12
sb --add item cal left \
   --set cal padding_left=12 padding_right=12 drawing=off updates=on update_freq=60 script="$P/next_event.sh" \
         click_script="$P/popup_click.sh cal" \
   --subscribe cal system_woke
