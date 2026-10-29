#!/bin/bash
# App menu popup: click the application name to see its menu bar.
#   title = app name, then "Settings…", then one row per menu (›), the open menu shows
#   its items as "└ item  shortcut". One menu is open at a time.
# Menus are read through the Accessibility API (helpers/bin/axmenu) only on a click:
# drawn at once from a per-app cache, then re-read in the background to refresh.
#   appmenu.sh open | render | refresh | toggle <menu> | press <menu> <item> [pid] | settings
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
flag_on "$APP_MENU" || exit 0
AX="$SBD_HELPERS/axmenu"; C="$SBD_CACHE/appmenu"; mkdir -p "$C"
IFS=$'\t' read -r PID NAME < <("$AX" front)
KEY="$C/$(printf '%s' "$NAME" | md5 | cut -c1-12)"; EXP="$C/expanded"
W=248; ROWS=32
ACT="@/bin/bash '$SBD_PLUGINS/appmenu.sh'"

refresh() {
  [ -n "$PID" ] && with_timeout 5 "$AX" menus "$PID" > "$KEY.tmp" 2>/dev/null && [ -s "$KEY.tmp" ] && mv "$KEY.tmp" "$KEY"
  rm -f "$KEY.tmp"
}
render() {
  local ex rows=() rights=() bgs=() i=0 k a b c d e
  ex=$(cat "$EXP" 2>/dev/null); [ "$(cut -f1 <<<"$ex")" = "$NAME" ] && ex=$(cut -f2 <<<"$ex") || ex=""
  rows+=("_"$'\t'"Settings…"$'\t'"$TEXT"$'\t'"/bin/bash '$SBD_PLUGINS/appmenu.sh' settings"); rights+=("⌘,|$TEXT3"); bgs+=("")
  while IFS=$'\t' read -r k a b c d e; do
    case "$k" in
      M) rows+=("_"$'\t'"$b"$'\t'"$TEXT2"$'\t'"$ACT toggle $a")
         if [ "$a" = "$ex" ]; then rights+=("−|$TEXT3"); bgs+=("$BG2"); else rights+=("›|$TEXT3"); bgs+=(""); fi ;;
      I) [ "$a" = "$ex" ] || continue
         if [ "$d" = 1 ]; then rows+=("_"$'\t'"└ $c"$'\t'"$TEXT"$'\t'"/bin/bash '$SBD_PLUGINS/appmenu.sh' press $a $b $PID")
         else rows+=("_"$'\t'"└ $c"$'\t'"$TEXT3"$'\t'""); fi
         rights+=("${e:+$e|$TEXT3}"); bgs+=("") ;;
    esac
  done < <(cat "$KEY" 2>/dev/null)
  [ -s "$KEY" ] || { rows+=("_"$'\t'"Reading menus …"$'\t'"$TEXT3"$'\t'); rights+=(""); bgs+=(""); }
  { for r in "${rows[@]:0:$ROWS}"; do printf '%s\n' "$r"; done; for ((j=${#rows[@]}; j<ROWS; j++)); do printf '~\t.\t\t\n'; done; } \
    | textfit 170 | nbsp2 | POPUP_W=$W popup_rows front_app "$(tr '[:lower:]' '[:upper:]' <<<"$NAME")"
  # Symbols and shortcuts (caption colour) are text images with their right edge at the
  # popup padding: two colours on one row. The open menu row gets the raised background.
  local x=()
  PX=()
  for ((i=0; i<ROWS; i++)); do
    x+=(--set front_app.p.$i background.image.drawing=off background.color=${bgs[$i]:-$CLEAR} label.y_offset=0 background.height=$POPUP_ROW_H)
    [ -n "${rights[$i]}" ] && popup_right front_app.p.$i "${rights[$i]%|*}" "${rights[$i]#*|}" $W
  done
  x+=(--set front_app.p.0 background.height=30 label.y_offset=3)
  sketchybar "${x[@]}" "${PX[@]}" 2>/dev/null
}
case "$1" in
  refresh) refresh; [ "$(cat "$POPUP_OPEN" 2>/dev/null)" = front_app ] && render ;;
  toggle) cur=$(cat "$EXP" 2>/dev/null); [ "$cur" = "$NAME"$'\t'"$2" ] && rm -f "$EXP" || printf '%s\t%s' "$NAME" "$2" > "$EXP"; render ;;
  press) popup_close_all
         # Do not press if the front app changed since drawing: the same numbers mean another menu.
         [ -n "$4" ] && [ "$4" != "$PID" ] && exit 0
         "$AX" press "$PID" "$2" "$3" ;;
  settings) popup_close_all; "$AX" settings "$PID" || osascript -e 'tell application "System Events" to keystroke "," using command down' ;;
  open) rm -f "$EXP"; render; /bin/bash "$SBD_PLUGINS/popup_click.sh" front_app
        [ "$(cat "$POPUP_OPEN" 2>/dev/null)" = front_app ] && { refresh; render; } ;;
  *) render ;;
esac
