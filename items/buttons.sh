#!/bin/bash
# Round buttons and capsules outside the right island, left of it:
#   [settings] [pilo] [docker notif ci] [ports|tailscale capsule] 5 [right island]

spacer isl.gap right $ISLAND_GAP

# ── Ports and Tailscale capsule ───────────────────────────────────────────────
# Pixel icons are PNGs drawn by lib/pixel.py in the theme colours.
PXI="icon.background.drawing=on icon.background.color=$CLEAR icon.background.image.scale=0.5 icon.background.image.drawing=on \
icon.padding_left=0 icon.padding_right=0 label.drawing=off"
sb --add item ts right \
   --set ts drawing=off icon="" icon.width=12 $PXI padding_left=0 padding_right=10 \
         icon.background.image="$SBD_CACHE/px/ts_off.png" update_freq=30 updates=on popup.align=left \
         script="$P/tailscale.sh" click_script="$P/popup_click.sh ts; $P/tailscale.sh refresh &" \
   --subscribe ts system_woke
PORTS_DRAWING=off; flag_on "$SHOW_PORTS" && PORTS_DRAWING=on
sb --add item ports right \
   --set ports drawing=$PORTS_DRAWING icon="" icon.width=12 $PXI padding_left=0 padding_right=18 \
         icon.background.image="$SBD_CACHE/px/port.png" update_freq=15 updates=on popup.align=left \
         script="$P/ports.sh" click_script="$P/popup_click.sh ports"
spacer apps.pad right 11

# ── Pilo ──────────────────────────────────────────────────────────────────────
# Hidden until `pilo` answers; pilo.sh turns it on. updates=on: a hidden item gets no
# periodic updates by default and would never come back.
sb --add item pilo right \
   --set pilo icon="" icon.width=$BUTTON_SIZE icon.padding_left=0 icon.padding_right=0 label.drawing=off \
         padding_left=0 padding_right=15 y_offset=0 drawing=off $BUTTON \
         background.image="$SBD_CACHE/px/pilo_idle_1.png" background.image.scale=0.5 background.image.drawing=on \
         update_freq=30 updates=on script="$P/pilo.sh" click_script="$P/popup_click.sh pilo.ul" \
   --subscribe pilo pilo_change system_woke \
   --add item pilo.ul right \
   --set pilo.ul icon.drawing=off label="" label.width=12 padding_left=0 padding_right=-22 popup.align=left \
         y_offset=0 drawing=off click_script="$P/popup_click.sh pilo.ul"

# ── Status chips: only present when there is something to show ────────────────
sb --add item docker right \
   --set docker icon=docker padding_left=12 padding_right=12 drawing=off updates=on update_freq=30 popup.align=left \
         script="$P/docker.sh" click_script="$P/popup_click.sh docker" \
   --add item notif right \
   --set notif icon=notif icon.padding_left=12 drawing=off updates=on update_freq=30 script="$P/notif.sh" \
   --add item ci right \
   --set ci icon.drawing=off label.color=$ERR padding_left=12 drawing=off updates=on update_freq=120 popup.align=left \
         script="$P/ci.sh" click_script="$P/popup_click.sh ci"

# ── Settings ──────────────────────────────────────────────────────────────────
SETTINGS_GLYPH=$'\xf3\xb0\x98\xae'   # nf-md-tune
sb --add item settings right \
   --set settings icon="$SETTINGS_GLYPH" icon.font="$ICON_FONT:Regular:14.0" icon.color=$TEXT icon.width=$BUTTON_SIZE \
         icon.align=center icon.padding_left=0 icon.padding_right=0 icon.y_offset=2 label.drawing=off \
         $BUTTON y_offset=0 padding_left=0 padding_right=5 click_script="$P/edit_config.sh"
