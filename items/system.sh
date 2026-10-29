#!/bin/bash
# Brackets (islands), underlines for open popups, popup defaults and the system popup.
sb_flush

# ── Islands ───────────────────────────────────────────────────────────────────
ISL="background.color=$ISLAND_FILL background.height=$ISLAND_HEIGHT background.corner_radius=$ISLAND_RADIUS \
background.border_width=1 background.border_color=$LINE background.drawing=on"
sb --default y_offset=0   # brackets and popups stay in place; only item text is raised

LEFT_ITEMS="wordmark space.padl space.padr app.padl front_app cwd git cal"
RIGHT_ITEMS="agent.gap agent agent.claude agent.codex agent.gemini agent.opencode bat bat.1 bat.2 bat.3 bat.4 bat.5 wifi clock"
flag_on "$SYSTEM_MENU" && RIGHT_ITEMS="$RIGHT_ITEMS cpu.ul cpu"
sb --add bracket island.left $LEFT_ITEMS --set island.left $ISL \
   --add bracket island.right $RIGHT_ITEMS --set island.right $ISL
if flag_on "$SHOW_MEDIA"; then
  sb --add bracket island.media media media.eq.1 media.eq.2 media.eq.3 media.prev media.play media.next \
        vol.sep vol vol.1 vol.2 vol.3 vol.4 vol.5 vol.pad --set island.media $ISL
fi
sb_flush
[ -f "$SBD_CACHE/spaces.n" ] && rm -f "$SBD_CACHE/spaces.n"
"$P/spaces.sh"   # draws the space dots; later brackets are on top, so this follows the island

# ── Underline of the open popup's parent cell ─────────────────────────────────
# Text colour, 2pt, just inside the island's bottom border. Round buttons and the
# capsule sit 12-13pt higher. popup_toggle turns it on and off.
UL="background.drawing=off background.color=$TEXT background.height=2 background.y_offset=$(( 1 - ISLAND_HEIGHT / 2 ))"
UL_ITEMS="clock wifi ports ts cpu.ul pilo.ul docker ci cal front_app"
flag_on "$SHOW_MEDIA" && UL_ITEMS="$UL_ITEMS media vol.ul"
for i in $UL_ITEMS; do sb --set $i $UL; done
sb --set ports background.y_offset=-13 --set ts background.y_offset=-13 \
   --set cpu.ul background.y_offset=-12 --set pilo.ul background.y_offset=-12
sb --add bracket apps.cap apps.pad ports ts --set apps.cap background.drawing=off background.color=$BG \
      background.height=$BUTTON_SIZE background.corner_radius=$(( BUTTON_RADIUS + 1 )) \
      background.border_width=1 background.border_color=$LINE
sb --add bracket agent.u agent agent.claude agent.codex agent.gemini agent.opencode \
   --set agent.u $UL background.y_offset=$(( 2 - ISLAND_HEIGHT / 2 )) \
   --add bracket bat.u bat bat.1 bat.2 bat.3 bat.4 bat.5 \
   --set bat.u $UL background.y_offset=$(( 2 - ISLAND_HEIGHT / 2 ))

PARENTS="cpu.ul pilo.ul bat agent ports ts docker ci cal wifi clock front_app"
flag_on "$SHOW_MEDIA" && PARENTS="$PARENTS media vol.ul"
for p in $PARENTS; do
  sb --set $p popup.height=1 popup.y_offset=$POPUP_Y popup.background.drawing=on popup.blur_radius=$POPUP_BLUR \
        popup.background.color=$POPUP_FILL popup.background.border_color=$LINE \
        popup.background.border_width=$POPUP_BORDER popup.background.corner_radius=$POPUP_RADIUS
done

# ── System popup: stats line and the power row ────────────────────────────────
if flag_on "$SYSTEM_MENU"; then
  SYS_BTN="icon.width=39 icon.align=center icon.padding_left=0 icon.padding_right=0 label.drawing=off \
padding_left=4 padding_right=4 background.drawing=on background.color=$BG2 background.height=34 \
background.corner_radius=$CONTROL_RADIUS background.border_width=1 background.border_color=$LINE"
  SYS_FONT="$ICON_FONT:Regular:16.0"
  sb --set cpu.ul popup.horizontal=on popup.align=right popup.height=44
  sb --add item sys.stats popup.cpu.ul \
     --set sys.stats icon.drawing=off label="CPU —  RAM —  DISK —" label.font="$FONT_SMALL" label.color=$TEXT2 \
           label.width=210 label.align=left label.padding_left=10 label.padding_right=2 \
           padding_left=4 padding_right=8 background.drawing=off
  for act in sleep restart shutdown; do
    case $act in
      sleep)    glyph=$'\xef\x86\x86'; col=$TEXT ;;
      restart)  glyph=$'\xef\x80\xa1'; col=$TEXT ;;
      shutdown) glyph=$'\xef\x80\x91'; col=$ERR ;;
    esac
    sb --add item sys.$act popup.cpu.ul \
       --set sys.$act $SYS_BTN icon="$glyph" icon.font="$SYS_FONT" icon.color=$col \
             click_script="$P/power.sh $act"
  done
fi

# ── Click shield ──────────────────────────────────────────────────────────────
# On macOS 27 a click on an empty part of the bar raises the bar background window
# above the item windows and hides all text (SketchyBar #850). A transparent bracket
# around the two end items makes that window rise instead. Only end items: items that
# get removed and re-created (space dots, popup rows) inside a bracket crash SketchyBar.
SHIELD_FIRST=wordmark; flag_on "$SHOW_CONTROL_CENTER" && SHIELD_FIRST=ctrlcenter
SHIELD_LAST=clock; flag_on "$SYSTEM_MENU" && SHIELD_LAST=cpu
sb --add bracket shield $SHIELD_FIRST $SHIELD_LAST \
   --set shield background.drawing=on background.color=$CLEAR background.height=$ISLAND_HEIGHT
sb_flush
