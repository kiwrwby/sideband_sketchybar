#!/bin/bash
# Clock text, every second. Runs 86400 times a day, so it avoids the full bootstrap:
# the settings it needs are cached in clock.env by the first run after a config change.
. "${0%/*}/../lib/paths.sh"
ENV="$SBD_CACHE/clock.env"
if [ ! -s "$ENV" ] || [ "$SBD_CONFIG" -nt "$ENV" ] || [ "$SBD_ROOT/config/defaults.sh" -nt "$ENV" ]; then
  . "${0%/*}/../lib/env.sh"
  printf 'CLOCK_FORMAT=%s CLOCK_AMPM=%s CLOCK_LEADING_ZERO=%s\n' "$CLOCK_FORMAT" "$CLOCK_AMPM" "$CLOCK_LEADING_ZERO" > "$ENV"
fi
. "$ENV"

IFS='|' read -r d h24 h12 ap <<<"$(LC_ALL=C date '+%m.%d|%H:%M|%I:%M|%p')"
if [ "$CLOCK_FORMAT" = 12 ]; then
  t=$h12
  [ "$CLOCK_LEADING_ZERO" = 1 ] || t=${t#0}
  case "$CLOCK_AMPM" in
    off|none|0) ;;
    upper|on|1) t="$t $ap" ;;
    *) t="$t $(printf '%s' "$ap" | tr '[:upper:]' '[:lower:]')" ;;
  esac
else
  t=$h24
fi
sketchybar --set clock icon="$d" label="$t"
