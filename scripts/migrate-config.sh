#!/bin/bash
# Convert a config.sh from the original sketchybar-island layout (or any older sideband
# config) into a sideband user config on stdout. Only values that differ from the
# current defaults are written, so the result stays short.
#   scripts/migrate-config.sh ~/.config/sketchybar/config.sh > ~/.config/sideband/config.sh
# The old file is sourced in a subshell. Nothing is modified.
set -e
OLD="${1:?usage: migrate-config.sh <old config.sh>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
[ -r "$OLD" ] || { echo "cannot read $OLD" >&2; exit 1; }

(
  . "$ROOT/config/defaults.sh"
  # Remember the defaults, then source the old file over them.
  for v in $(awk -F= '/^[A-Z][A-Z0-9_]*=/{print $1}' "$ROOT/config/defaults.sh"); do
    eval "DEF_$v=\"\${$v-}\""
  done
  DEF_WORDMARK_PHRASES=("${WORDMARK_PHRASES[@]}"); DEF_AGENT_ORDER=("${AGENT_ORDER[@]}"); DEF_NOTIF_APPS=("${NOTIF_APPS[@]}")
  # shellcheck disable=SC1090
  . "$OLD" >/dev/null 2>&1 || true

  # The original showed directory and branch whenever the shell hook ran.
  SHOW_CWD=1; SHOW_GIT=1
  # old name -> new name
  [ -n "${NOTCH_H-}" ] && ISLAND_HEIGHT=$NOTCH_H
  [ -n "${BAR_OPACITY-}" ] && ISLAND_OPACITY=$BAR_OPACITY
  [ -n "${PANEL_FONT-}" ] && FONT_FAMILY=$PANEL_FONT
  [ -n "${PANEL_FONT_STYLE-}" ] && FONT_STYLE=$PANEL_FONT_STYLE
  [ -n "${PANEL_FONT_SIZE-}" ] && FONT_SIZE=${PANEL_FONT_SIZE%.0}
  [ -n "${CLOCK_12H_LEADING_ZERO-}" ] && CLOCK_LEADING_ZERO=$CLOCK_12H_LEADING_ZERO
  [ -n "${WORK_DIR-}" ] && PORTS_ROOT=$WORK_DIR
  [ -n "${PILO_ISLAND-}" ] && { [ "$PILO_ISLAND" = 0 ] && SHOW_PILO=0; }
  [ -n "${PILO_ANIM-}" ] && PILO_ANIMATE=$PILO_ANIM
  # Old files set these to 0/1 only; keep 0 as an explicit opt-out, 1 becomes auto.
  for p in CLAUDE CODEX; do eval "v=\${SHOW_${p}_AGENT-}"; [ "$v" = 1 ] && eval "SHOW_${p}_AGENT=auto"; done

  echo "# sideband config, migrated from $OLD on $(date +%F)."
  echo "# Only values that differ from config/defaults.sh are listed."
  for v in $(awk -F= '/^[A-Z][A-Z0-9_]*=/{print $1}' "$ROOT/config/defaults.sh"); do
    case " WORDMARK_PHRASES AGENT_ORDER NOTIF_APPS " in *" $v "*) continue ;; esac
    eval "cur=\"\${$v-}\""; eval "def=\"\${DEF_$v-}\""
    [ "$cur" = "$def" ] || printf '%s=%q\n' "$v" "$cur"
  done
  for arr in WORDMARK_PHRASES AGENT_ORDER NOTIF_APPS; do
    eval "cur=(\"\${$arr[@]}\")"; eval "def=(\"\${DEF_$arr[@]}\")"
    if [ "${cur[*]}" != "${def[*]}" ]; then
      printf '%s=(\n' "$arr"; for e in "${cur[@]}"; do printf '  %q\n' "$e"; done; printf ')\n'
    fi
  done
)
