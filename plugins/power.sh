#!/bin/bash
# System popup actions. Restart and shut down always ask first.
#   power.sh sleep | restart | shutdown
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
case "${1:-}" in sleep|restart|shutdown) ;; *) echo "usage: power.sh sleep|restart|shutdown" >&2; exit 2 ;; esac
popup_close_all
PMSET=${SBD_PMSET:-/usr/bin/pmset}; OSA=${SBD_OSASCRIPT:-/usr/bin/osascript}   # overridable for tests
case "$1" in
  sleep) exec "$PMSET" sleepnow ;;
  restart)  TITLE="Restart this Mac?";   BTN="Restart";   VERB="restart" ;;
  shutdown) TITLE="Shut down this Mac?"; BTN="Shut Down"; VERB="shut down" ;;
esac
# Cancel is the default button, so a stray Return never powers the Mac off.
ANSWER=$("$OSA" -e "display dialog \"$TITLE\" buttons {\"Cancel\", \"$BTN\"} default button \"Cancel\" with icon caution" 2>/dev/null) || exit 0
case "$ANSWER" in
  *"button returned:$BTN"*) "$OSA" -e "tell application \"System Events\" to $VERB" ;;
esac
