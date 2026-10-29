#!/bin/bash
# Right island, built right to left (the first item added is the rightmost):
#   [agents] [battery] [wifi] [clock] [cat]
# Round buttons and optional capsules sit outside it, see buttons.sh.

# ── System menu trigger: the pixel cat ────────────────────────────────────────
python3 "$SBD_ROOT/lib/pixel.py" icons "$SBD_CACHE/px" "$TEXT" "$TEXT3" "$WARN" "$ERR" "$BG" "$LINE" "$ACCENT"
if flag_on "$SYSTEM_MENU"; then
  sb --add item cpu right \
     --set cpu icon="" icon.width=$BUTTON_SIZE icon.padding_left=0 icon.padding_right=0 label.drawing=off \
           padding_left=0 padding_right=$CAT_RIGHT_PAD y_offset=0 $BUTTON \
           background.image="$SBD_CACHE/px/cat_1.png" background.image.scale=0.5 background.image.drawing=on \
           update_freq=5 script="$P/system.sh" click_script="$P/popup_click.sh cpu.ul" \
     --subscribe cpu power_source_change volume_change system_woke \
     --add item cpu.ul right \
     --set cpu.ul icon.drawing=off label="" label.width=12 padding_left=0 padding_right=-22 popup.align=right y_offset=0 \
           click_script="$P/popup_click.sh cpu.ul"
fi

# ── Clock ─────────────────────────────────────────────────────────────────────
sb --add item clock right \
   --set clock padding_left=12 padding_right=$CLOCK_CAT_GAP icon.padding_right=8 icon.font="$FONT_CLOCK" \
         label.font="$FONT_CLOCK" update_freq=1 script="$P/clock.sh" popup.align=right \
         click_script="$P/popup_click.sh clock" \
   --subscribe clock system_woke \
   --add item clock.cal right --set clock.cal drawing=off updates=on update_freq=10 script="$P/calendar.sh" \
   --subscribe clock.cal system_woke
flag_on "$SHOW_DATE" || sb --set clock icon.drawing=off

# ── Wi-Fi ─────────────────────────────────────────────────────────────────────
sb --add item wifi right \
   --set wifi icon="wifi" padding_left=$CELL_GAP icon.padding_right=8 padding_right=12 update_freq=30 popup.align=right \
         script="$P/wifi.sh" click_script="$P/wifi_scan.sh" \
   --subscribe wifi wifi_change system_woke

# ── Battery ───────────────────────────────────────────────────────────────────
for c in 5 4 3 2 1; do
  gap=2; [ $c = 5 ] && gap=0
  sb --add item bat.$c right \
     --set bat.$c icon.drawing=off label="" label.width=4 background.height=10 background.color=$LINE \
           background.drawing=on padding_right=$gap click_script="$P/popup_click.sh bat"
done
sb --add item bat right \
   --set bat icon=bat icon.padding_left=0 icon.padding_right=4 label.drawing=off update_freq=30 popup.align=left \
         script="$P/battery.sh" click_script="$P/popup_click.sh bat" \
   --subscribe bat power_source_change system_woke
case "$BATTERY_MODE" in
  percent)
    sb --set bat drawing=on icon.drawing=off label.drawing=on label="—%" label.width=dynamic label.color=$TEXT \
          padding_left=16 padding_right=$CELL_GAP
    for i in 1 2 3 4 5; do sb --set bat.$i drawing=off; done ;;
  hidden)
    sb --set bat drawing=off
    for i in 1 2 3 4 5; do sb --set bat.$i drawing=off; done ;;
  bar) ;;
  *) echo "sideband: unknown BATTERY_MODE=$BATTERY_MODE (bar | percent | hidden)" >&2 ;;
esac

# ── Agents ────────────────────────────────────────────────────────────────────
# Glyphs come from the Nerd Font Propo: the Mono variant shrinks them to one cell.
AG_FONT="$ICON_FONT:Regular:14.0"

for kind in opencode gemini; do
  case $kind in opencode) g=OC; gf="$FONT_FAMILY:Bold:11.0" ;; gemini) g=G; gf="$FONT_FAMILY:Bold:12.0" ;; esac
  sb --add item agent.$kind right \
     --set agent.$kind icon="$g" icon.font="$gf" icon.color=$TEXT2 icon.padding_right=4 label="—" label.color=$TEXT2 \
           padding_right=12 drawing=off updates=on update_freq=60 script="$P/agents.sh $kind" \
           click_script="$P/popup_click.sh agent"
done
sb --add item agent.codex right \
   --set agent.codex icon=$'\xee\xb2\x81' icon.font="$AG_FONT" icon.color=$TEXT icon.padding_right=4 label="—" \
         label.color=$TEXT3 padding_right=$CELL_GAP drawing=off click_script="$P/popup_click.sh agent" \
   --add item agent.claude right \
   --set agent.claude icon=$'\xee\xb2\x82' icon.font="$AG_FONT" icon.color=$BRAND_CLAUDE icon.padding_right=4 label="—" \
         label.color=$TEXT3 padding_right=12 drawing=off click_script="$P/popup_click.sh agent" \
   --add item agent right \
   --set agent icon=agent icon.padding_right=8 label.drawing=off update_freq=15 updates=on popup.align=left drawing=off \
         script="$P/agents.sh" click_script="$P/popup_click.sh agent"
spacer agent.gap right $ISLAND_PAD

# Order inside the group. Right-aligned items are laid out right to left, and
# "--move X after Y" puts X on the left of Y. Build from the notch side outwards.
ORDER=$(printf '%s\n' "${AGENT_ORDER[@]}" claude codex gemini opencode | awk '/^(claude|codex|gemini|opencode)$/ && !s[$0]++')
prev=bat
for kind in $(printf '%s\n' $ORDER | sed '1!G;h;$!d'); do   # reversed: last in order sits next to the battery
  sb --move "agent.$kind" after "$prev"; prev="agent.$kind"
done
sb --move agent after "$prev" --move agent.gap after agent
