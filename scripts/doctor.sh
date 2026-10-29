#!/bin/bash
# Read-only health check of an installed sideband. Changes nothing.
#   scripts/doctor.sh        exit status 1 if something is wrong
# Check the installed copy, even when started from a checkout: daemons run from there.
INSTALLED=$(grep '^PREFIX=' "$HOME/.local/state/sideband/install.env" 2>/dev/null | tail -1 | cut -d= -f2-)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [ -n "$INSTALLED" ] && [ -x "$INSTALLED/scripts/doctor.sh" ] && [ "$(cd "$INSTALLED" && pwd -P)" != "$HERE" ]; then
  exec /bin/bash "$INSTALLED/scripts/doctor.sh" "$@"
fi
. "$HERE/lib/env.sh"
BAD=0
ok()   { printf '  ok    %s\n' "$*"; }
warn() { printf '  warn  %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; BAD=1; }

echo "system"
ok "macOS $(sw_vers -productVersion), $(uname -m)"
for f in "$SBD_HELPERS/textwidth" "$SBD_HELPERS/notch" "$SBD_HELPERS/clickaway" "$SBD_HELPERS/WifiScan.app/Contents/MacOS/WifiScan"; do
  [ -x "$f" ] || bad "helper missing: ${f#$SBD_ROOT/}. Run helpers/build.sh"
done
command -v jq >/dev/null && ok "jq" || bad "jq is missing (brew install jq)"

echo "sketchybar"
SB=$(command -v sketchybar || echo /opt/homebrew/bin/sketchybar)
if [ -x "$SB" ]; then
  V=$("$SB" --version 2>/dev/null); ok "$V ($(readlink -f "$SB" 2>/dev/null || echo "$SB"))"
  case "$(readlink "$SB" 2>/dev/null)" in *fix852*) ok "patched build for SketchyBar#852" ;;
    *) [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 27 ] && warn "upstream SketchyBar on macOS 27: clicks may be lost (install.sh --patched-sketchybar)" ;; esac
else bad "sketchybar not found"; fi
L=$(launchctl list 2>/dev/null | awk '/sketchybar/ {print $1, $3; exit}')
[ -n "$L" ] && ok "launchd job: $L" || warn "no launchd job for sketchybar (brew services start sketchybar)"
n=$(/usr/bin/pgrep -f '^(/[^ ]*/)?sketchybar( --config .*)?$' | wc -l | tr -d ' ')
[ "$n" = 1 ] && ok "one server running" || bad "$n SketchyBar servers running (expected 1)"
if [ -f "$SBD_CACHE/ready" ]; then ok "bar loaded $(( $(date +%s) - $(stat -f %m "$SBD_CACHE/ready") )) s ago"; else warn "no ready marker: the bar has not finished loading"; fi
for d in "$SBD_CACHE"/run/*.pid; do
  [ -f "$d" ] || continue; name=${d##*/}; name=${name%.pid}
  sbd_running "$name" && ok "daemon $name" || warn "daemon $name is not running (stale pidfile; it may be switched off)"
done
dup=$(ps -axo command= | grep -c "[$(printf '%s' "${SBD_PLUGINS:0:1}")]${SBD_PLUGINS:1}/wordmark.sh$")
[ "$dup" -le 2 ] || bad "$dup wordmark daemons (a pipeline shows twice; more means duplicates)"

echo "config"
[ -f "$SBD_CONFIG" ] && ok "$SBD_CONFIG" || warn "no user config: defaults are used"
if [ -f "$SBD_CONFIG" ]; then
  /bin/bash -n "$SBD_CONFIG" 2>/dev/null && ok "syntax" || bad "syntax error in $SBD_CONFIG"
  for k in $(grep -oE '^[A-Z][A-Z0-9_]*=' "$SBD_CONFIG" | tr -d =); do
    grep -q "^$k=" "$SBD_ROOT/config/defaults.sh" || warn "unknown option $k (typo?)"
  done
fi
fontfound() { [ "$("$SBD_HELPERS/textwidth" "$1" Regular 12 exists)" = 1 ]; }
for f in "$FONT_FAMILY" "$ICON_FONT"; do
  fontfound "$f" && ok "font $f" || warn "font \"$f\" not found, SketchyBar will substitute one (brew install --cask font-jetbrains-mono font-jetbrains-mono-nerd-font)"
done

echo "helpers and permissions"
"$SBD_HELPERS/events" today >/dev/null 2>&1; [ $? = 3 ] && warn "Calendar access denied: the calendar popup shows no events" || ok "Calendar access not denied"
st=$(head -1 "$SBD_CACHE/ssid.txt" 2>/dev/null); case "$st" in ok) ok "Wi-Fi name readable" ;; denied) warn "Location denied: the Wi-Fi name is hidden (Privacy & Security, Location Services)" ;; *) warn "Wi-Fi name not read yet" ;; esac
pid=$("$SBD_HELPERS/axmenu" front 2>/dev/null | cut -f1)
[ -n "$pid" ] && [ -n "$("$SBD_HELPERS/axmenu" menus "$pid" 2>/dev/null | head -1)" ] && ok "Accessibility works for this terminal" || warn "no menus read: allow Accessibility for the app that runs this (and for sketchybar)"
if flag_on "$SHOW_MEDIA"; then
  find_cli media-control >/dev/null && ok "media-control" || warn "SHOW_MEDIA=1 but media-control is missing (brew install media-control; Apple Music works without)"
fi
echo "zapmenu"
if /usr/bin/pgrep -x zapmenu >/dev/null; then ok "running"; else warn "not running: the macOS menu bar may drop over the bar"; fi

[ $BAD = 0 ] && echo "no failures" || echo "problems found"
exit $BAD
