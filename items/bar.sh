#!/bin/bash
# Bar, defaults, shared events and the invisible service items.

sb --bar position=top height=$ISLAND_HEIGHT notch_display_height=$ISLAND_HEIGHT color=$CLEAR \
   blur_radius=0 border_width=0 corner_radius=0 shadow=off margin=$ISLAND_GAP y_offset=$BAR_AWAY \
   padding_left=0 padding_right=0 notch_width=$NOTCH_W display=$BAR_DISPLAY topmost=window
sb_flush

sb --default updates=when_shown \
   icon.font="$FONT_BASE" label.font="$FONT_BASE" icon.color=$TEXT3 label.color=$TEXT \
   icon.padding_left=0 icon.padding_right=6 label.padding_left=0 label.padding_right=0 \
   padding_left=0 padding_right=0 background.corner_radius=0 background.border_width=0 \
   popup.background.color=$POPUP_FILL popup.background.border_color=$LINE \
   popup.background.border_width=$POPUP_BORDER popup.background.corner_radius=$POPUP_RADIUS \
   popup.y_offset=$POPUP_Y
sb --default y_offset=$ITEM_DY

sb --add event media_update \
   --add event shell_cwd \
   --add event pilo_change \
   --add event theme_change AppleInterfaceThemeChangedNotification

# Service items draw nothing. They only carry event subscriptions.
sb --add item service.theme left --set service.theme drawing=off updates=on script="$P/theme_watch.sh" \
   --subscribe service.theme theme_change \
   --add item service.windows left --set service.windows drawing=off updates=on script="$P/automax.sh" \
   --subscribe service.windows space_windows_change \
   --add item service.guard left --set service.guard drawing=off updates=on script="$P/popup_guard.sh" \
   --subscribe service.guard front_app_switched space_change display_change system_woke

# SketchyBar's default is updates=when_shown: an item that is hidden gets no events and no
# periodic updates, so it could never come back. Every item that starts hidden and has a
# script sets updates=on. tests/test_rc.sh checks this.
spacer() { sb --add item "$1" "$2" --set "$1" width=${3:-12} icon.drawing=off label.drawing=off; }
# Round button: background circle with a centred icon or image
BUTTON="background.drawing=on background.color=$BG background.height=$BUTTON_SIZE background.corner_radius=$BUTTON_RADIUS \
background.border_width=1 background.border_color=$LINE"
