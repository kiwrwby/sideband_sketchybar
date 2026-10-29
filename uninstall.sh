#!/bin/bash
# Remove sideband without destroying anything of yours.
#
#   ./uninstall.sh [--restore] [--purge-config] [--purge-cache] [--dry-run] [-y]
#
#   --restore       put the SketchyBar config that existed before sideband back
#                   (the newest ~/.config/sketchybar.bak.*, or the one recorded at install)
#   --purge-config  also delete ~/.config/sideband (your edited config.sh). Off by default.
#   --purge-cache   also delete ~/.cache/sideband
#   --dry-run       print what would happen
#
# Always removed: the managed stub in ~/.config/sketchybar, the install directory,
# the zapmenu LaunchAgent this installer created. Never removed: Homebrew packages
# (sketchybar, fonts, media-control), a zapmenu you installed yourself, your
# ~/.config/sideband unless --purge-config. How to remove those is printed at the end.
# Bash 3.2 compatible.
DRY=0; RESTORE=0; PURGE_CONF=0; PURGE_CACHE=0; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --restore) RESTORE=1 ;; --purge-config) PURGE_CONF=1 ;; --purge-cache) PURGE_CACHE=1 ;;
    --dry-run) DRY=1 ;; -y|--yes) YES=1 ;;
    -h|--help) sed -n '2,/^# Bash 3.2/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac; shift
done
run() { if [ $DRY = 1 ]; then printf '   + %s\n' "$*"; else "$@"; fi; }
say() { printf '   %s\n' "$*"; }
[ "$(id -u)" = 0 ] && { echo "do not run as root" >&2; exit 1; }

CONF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SB_DIR="$CONF_HOME/sketchybar"; STATE="$HOME/.local/state/sideband/install.env"
PREFIX_DEFAULT="${SIDEBAND_PREFIX:-$HOME/.local/share/sideband}"
rec() { grep "^$1=" "$STATE" 2>/dev/null | tail -1 | cut -d= -f2-; }
PREFIX=$(rec PREFIX); PREFIX=${PREFIX:-$PREFIX_DEFAULT}
BACKUP=$(rec BACKUP); ZAP_PLIST=$(rec ZAP_PLIST); ZAP_BIN=$(rec ZAP_BIN_BY_US)
UID_=$(id -u)

# Safety: only touch ~/.config/sketchybar when it is ours.
if [ -e "$SB_DIR" ] && [ ! -f "$SB_DIR/.sideband-managed" ]; then
  echo "$SB_DIR is not managed by sideband (no .sideband-managed marker). Leaving it alone." >&2
  [ $RESTORE = 1 ] && exit 1
fi

[ $DRY = 1 ] && say "dry run: nothing will be changed"
printf '== Stop\n'
SB_LABEL=$(launchctl list 2>/dev/null | awk '/sketchybar/ {print $3; exit}')
for n in wordmark cat media_watch media_eq audio_watch pilo_anim; do
  p=$(cat "${XDG_CACHE_HOME:-$HOME/.cache}/sideband/run/$n.pid" 2>/dev/null)
  [ -n "$p" ] && ps -p "$p" -o command= 2>/dev/null | grep -qF "$PREFIX" && { run pkill -P "$p" 2>/dev/null; run kill "$p" 2>/dev/null; }
done

printf '== SketchyBar configuration\n'
if [ -f "$SB_DIR/.sideband-managed" ]; then
  run rm -f "$SB_DIR/sketchybarrc" "$SB_DIR/.sideband-managed"
  run rmdir "$SB_DIR" 2>/dev/null
  say "removed the managed stub"
fi
if [ $RESTORE = 1 ]; then
  if [ -z "$BACKUP" ] || [ ! -d "$BACKUP" ]; then BACKUP=$(ls -d "$CONF_HOME"/sketchybar.bak.* 2>/dev/null | sort | tail -1); fi
  if [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; then
    if [ -e "$SB_DIR" ]; then say "$SB_DIR still exists and is not empty; not restoring over it"
    else run mv "$BACKUP" "$SB_DIR"; say "restored $BACKUP -> $SB_DIR"; fi
  else say "no backup found to restore"; fi
elif [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; then
  say "your earlier config is still at $BACKUP (restore with: ./uninstall.sh --restore)"
fi

printf '== Files\n'
if [ -L "$PREFIX" ]; then run rm "$PREFIX"; say "removed the link $PREFIX"
elif [ -d "$PREFIX" ] && { [ -f "$PREFIX/.sideband-install" ] || { [ -f "$PREFIX/sketchybarrc" ] && [ -f "$PREFIX/lib/env.sh" ]; }; }; then
  run rm -rf "$PREFIX"; say "removed $PREFIX"
elif [ -e "$PREFIX" ]; then say "$PREFIX does not look like a sideband install; left alone"; fi
if [ -n "$ZAP_PLIST" ] && [ -f "$ZAP_PLIST" ]; then
  run launchctl bootout "gui/$UID_" "$ZAP_PLIST" 2>/dev/null; run rm -f "$ZAP_PLIST"; say "removed the zapmenu LaunchAgent this installer created"
fi
if [ -n "$ZAP_BIN" ] && [ -f "$ZAP_BIN" ]; then run rm -f "$ZAP_BIN"; say "removed $ZAP_BIN (installed by sideband)"; fi
[ $PURGE_CONF = 1 ] && { run rm -rf "$CONF_HOME/sideband"; say "deleted $CONF_HOME/sideband"; } || say "kept $CONF_HOME/sideband (your config)"
[ $PURGE_CACHE = 1 ] && run rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/sideband"
run rm -f "$STATE"

printf '== Service\n'
if [ -n "$SB_LABEL" ]; then
  if [ -d "$SB_DIR" ]; then run launchctl kickstart -k "gui/$UID_/$SB_LABEL" && say "restarted $SB_LABEL on the restored config"
  else say "SketchyBar has no config now and keeps running empty. Stop it with: brew services stop sketchybar"; fi
fi
cat <<MSG

Left in place on purpose. Remove by hand if you want them gone:
  brew services stop sketchybar && brew uninstall sketchybar     (the SketchyBar build you run)
  brew uninstall --cask font-jetbrains-mono font-jetbrains-mono-nerd-font
  brew uninstall media-control
  Back to upstream SketchyBar after the #852 fix ships:  brew uninstall sketchybar && brew install felixkratz/formulae/sketchybar
MSG
