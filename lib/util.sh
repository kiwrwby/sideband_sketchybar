#!/bin/bash
# Shared helpers: batching, text metrics, daemon lifecycle, small formatters.

# ── Batching ──────────────────────────────────────────────────────────────────
# rc builds ~150 items. One sketchybar call per flush instead of 150 forks.
# A bad command inside a batch does not abort the rest.
SB_Q=()
sb() { SB_Q+=("$@"); }
sb_flush() {
  [ ${#SB_Q[@]} -gt 0 ] && command sketchybar "${SB_Q[@]}"
  SB_Q=()
}

# ── Text metrics ──────────────────────────────────────────────────────────────
# helpers/textwidth resolves the font the way SketchyBar does, so these are exact for any
# font, proportional ones included.
_tw() { "$SBD_HELPERS/textwidth" "$FONT_FAMILY" "$FONT_STYLE" "$FONT_SIZE" "$@"; }
textw() { _tw width "$1"; }                 # width of a string in points, rounded up
textprefixes() { _tw prefixes "$1"; }       # widths of its prefixes, 0..n characters
textfit() { _tw fit "$1"; }                 # stdin: tab separated lines; field 2 is cut to MAX pt with an ellipsis
# Advance of one cell of the fixed-pitch font for grids (calendar). FONT_MONO, else FONT_FAMILY.
sbd_mono_adv() { "$SBD_HELPERS/textwidth" "$FONT_MONO" Regular "$FONT_SIZE" adv; }

# ── Formatting ────────────────────────────────────────────────────────────────
# Popups strip leading spaces. Turn spaces in field 2 into NBSP so alignment holds.
nbsp2() { awk -F'\t' -v OFS='\t' '{ gsub(/ /, "\302\240", $2) } 1'; }
img_w() { echo $(( $(sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/{print $2}') / 2 )); }   # png width in pt @2x

# ── Daemon lifecycle ──────────────────────────────────────────────────────────
# Long-running loops (wordmark, cat, media watcher...) are started by rc and
# tracked by pidfile. Stopping kills the recorded pid and its children, and only
# after checking that the pid still belongs to us (pids get reused).
sbd_pid() { cat "$SBD_CACHE/run/$1.pid" 2>/dev/null; }
sbd_running() {
  local p; p=$(sbd_pid "$1"); [ -n "$p" ] || return 1
  ps -p "$p" -o command= 2>/dev/null | grep -qF "$SBD_ROOT"
}
sbd_stop() {
  local p; p=$(sbd_pid "$1")
  if [ -n "$p" ] && ps -p "$p" -o command= 2>/dev/null | grep -qF "$SBD_ROOT"; then
    pkill -P "$p" 2>/dev/null
    kill "$p" 2>/dev/null
  fi
  rm -f "$SBD_CACHE/run/$1.pid"
}
sbd_start() {   # <name> <script> [args]: restart-safe, one instance per name
  local name=$1; shift
  sbd_stop "$name"
  # stderr goes to run/<name>.log (truncated per start): a daemon that dies leaves a reason.
  SBD_BAR_PID="${SBD_BAR_PID:-$(pgrep -f "^(/[^ ]*/)?sketchybar( --config .*)?\$" | head -1)}" nohup "$@" >/dev/null 2>"$SBD_CACHE/run/$name.log" &
  echo $! > "$SBD_CACHE/run/$name.pid"
}
# Start only if not running. Several plugin runs can ask at the same moment (a stream event
# and the periodic refresh), so the check and the start happen under a lock.
sbd_ensure() {   # <name> <command...>
  local name=$1 lock="$SBD_CACHE/run/$1.lock" n=0
  while ! mkdir "$lock" 2>/dev/null; do
    n=$((n + 1)); [ $n -gt 20 ] && { rmdir "$lock" 2>/dev/null; return 1; }   # a crashed holder: break the lock
    sleep 0.05
  done
  sbd_running "$name" || sbd_start "$@"
  rmdir "$lock" 2>/dev/null
}
# Daemons call this each loop: leave when SketchyBar is gone.
sbd_bar_alive() { [ -n "${SBD_BAR_PID:-}" ] && kill -0 "$SBD_BAR_PID" 2>/dev/null; }

# Reduce Motion stops every decorative loop.
sbd_reduce_motion() { [ "$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null)" = 1 ]; }

# Run a command with a hard time limit (seconds). macOS has no timeout(1).
with_timeout() { local t=$1; shift; perl -e 'alarm shift; exec @ARGV' "$t" "$@"; }

# Locate a CLI. SketchyBar's PATH is minimal, so look in the usual prefixes.
find_cli() {
  local n=$1 p
  p=$(command -v "$n" 2>/dev/null) && { printf '%s' "$p"; return 0; }
  for p in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/.orbstack/bin"; do
    [ -x "$p/$n" ] && { printf '%s' "$p/$n"; return 0; }
  done
  return 1
}

# Tri-state config flag: 1 | 0 | auto. "auto" resolves through the given command.
flag_on() {   # <value> [detect command...]
  local v=$1; shift
  case "$v" in 1|on|true) return 0 ;; 0|off|false|"") return 1 ;; esac
  [ $# -gt 0 ] && "$@"
}
