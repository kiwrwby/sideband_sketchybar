#!/bin/bash
# Wi-Fi click: open or close the popup and scan only when opening (about 6 s,
# "Scanning ..." shows meanwhile), then list again.
. "${0%/*}/../lib/env.sh"
/bin/bash "$SBD_PLUGINS/popup_click.sh" wifi
[ "$(cat "$SBD_CACHE/popup_open" 2>/dev/null)" = wifi ] || exit 0
APP="$SBD_HELPERS/WifiScan.app/Contents/MacOS/WifiScan"
[ -x "$APP" ] || exit 0
touch "$SBD_CACHE/wifiscan.busy"; SENDER=routine NAME=wifi /bin/bash "$SBD_PLUGINS/wifi.sh"
# Run the executable directly. Launching the app with `open` closes the popup: the
# popup is not drawn until a real click.
SBD_CACHE="$SBD_CACHE" with_timeout 20 "$APP" scan
rm -f "$SBD_CACHE/wifiscan.busy"; SENDER=routine NAME=wifi /bin/bash "$SBD_PLUGINS/wifi.sh"
