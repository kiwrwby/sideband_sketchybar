#!/bin/bash
# Bar item click: close the other popups, open or close this one.
#   popup_click.sh <popup parent>
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
popup_toggle "$1"
