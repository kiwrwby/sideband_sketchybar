#!/bin/bash
# Maximizes newly opened windows through Rectangle. AUTOMAX=1 to enable.
. "${0%/*}/../lib/env.sh"
flag_on "$AUTOMAX" || exit 0
open -Ra Rectangle >/dev/null 2>&1 || exit 0   # without Rectangle there is nothing to call
sleep 0.3   # let the window settle
[ "$(SBD_CACHE="$SBD_CACHE" "$SBD_HELPERS/newwin" "$AUTOMAX_EXCLUDE" "$AUTOMAX_INCLUDE")" = max ] \
  && open -g "rectangle://execute-action?name=maximize"
