#!/bin/bash
# Settings button: edit the config in a terminal window. When the editor closes the
# config is syntax-checked; on success the bar reloads, on failure it asks to reopen.
#   edit_config.sh          open the editor window
#   edit_config.sh run      (internal) the command the window runs
. "${0%/*}/../lib/env.sh"
CFG="$SBD_CONFIG"
# The file must show every option, active. A new one is rendered in full. An older one
# gets the options it lacks appended; nothing of yours is touched, a backup is kept.
RENDER="$SBD_ROOT/scripts/render_config.py"
if [ "$1" != run ]; then
  mkdir -p "${CFG%/*}"
  if [ ! -f "$CFG" ]; then
    /usr/bin/python3 -I "$RENDER" "$SBD_ROOT/config/defaults.sh" > "$CFG"
  else
    add=$(/usr/bin/python3 -I "$RENDER" --missing "$SBD_ROOT/config/defaults.sh" "$CFG")
    if [ -n "$add" ]; then
      cp "$CFG" "$CFG.bak-$(date +%Y%m%d-%H%M%S)"
      printf '\n# Options added since this file was written:\n%s\n' "$add" >> "$CFG"
    fi
  fi
fi
if [ "$1" != run ]; then
  if [ -d "/Applications/$TERMINAL_APP.app" ] && [ "$TERMINAL_APP" = Ghostty ]; then
    # The command goes in as one string: a bare path makes Ghostty ask "run this?".
    open -na /Applications/Ghostty.app --args --window-width=100 --window-height=36 -e /bin/bash -c "'$SBD_PLUGINS/edit_config.sh' run"
  elif [ -d "/Applications/$TERMINAL_APP.app" ]; then
    open -a "$TERMINAL_APP" "$CFG"   # no command-line contract for other terminals: open the file instead
  else
    open -t "$CFG"
  fi
  exit 0
fi
ED="${EDITOR_CMD:-${EDITOR:-nano}}"
GP=$(ps -o ppid= -p $PPID | tr -d ' ')   # the Ghostty instance that opened this window
bye() { ps -o command= -p "$GP" | grep -q 'ghostty.*edit_config' && kill "$GP"; exit "${1:-0}"; }
while :; do
  $ED "$CFG"
  if err=$(/bin/bash -n "$CFG" 2>&1); then   # the bar runs the config with /bin/bash 3.2
    sketchybar --reload && echo "saved, sketchybar reloaded" && sleep 1
    bye 0
  fi
  printf '\nsyntax error, not reloaded:\n%s\n\nreopen? [Y/n] ' "$err"; read -r a
  [ "$a" = n ] && bye 1
done
