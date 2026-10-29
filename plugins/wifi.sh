#!/bin/bash
# Wi-Fi item and popup: ssid, ip, router, saved networks in range, settings.
#
# macOS hides the network name from programs without Location permission, so the
# name comes from helpers/bin/WifiScan.app (it holds that permission). It runs on
# network change, wake and start, and the result is cached in ssid.txt.
# The scan list only refreshes when the popup opens (wifi_scan.sh).
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
APP="$SBD_HELPERS/WifiScan.app/Contents/MacOS/WifiScan"

IF=$(cat "$SBD_CACHE/wifi_if" 2>/dev/null)
[ -n "$IF" ] || { IF=$(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2; exit}'); echo "${IF:-en0}" > "$SBD_CACHE/wifi_if"; IF=${IF:-en0}; }
IP=$(ipconfig getifaddr "$IF" 2>/dev/null)

refresh_name() { [ -x "$APP" ] && SBD_CACHE="$SBD_CACHE" with_timeout 8 "$APP" current >/dev/null 2>&1; }
case "$SENDER" in
  wifi_change|system_woke|forced) [ -n "$SB_BOOT" ] || refresh_name ;;
esac
# First pass only has the cached name. Refresh it in the background; SB_BOOT must be
# cleared for the child, or it would spawn another one, forever.
[ -n "$SB_BOOT" ] && ( SB_BOOT= SENDER=forced nohup /bin/bash "$0" >/dev/null 2>&1 & )

SSID=""
if [ -n "$IP" ]; then
  SSID=$(sed -n 2p "$SBD_CACHE/ssid.txt" 2>/dev/null)
  [ -n "$SSID" ] || { SSID=$(ipconfig getsummary "$IF" 2>/dev/null | awk -F ' SSID : ' '/ SSID : /{print $2}'); [ "$SSID" = "<redacted>" ] && SSID=""; }
fi

# ── Bar ───────────────────────────────────────────────────────────────────────
# Over 16 characters the name becomes 15 + an ellipsis.
# With SHOW_WIFI_NAME=0 the bar says "on" and the popup says "hidden": nothing names the network.
NAME_SHOWN=$SSID; flag_on "$SHOW_WIFI_NAME" || NAME_SHOWN=""
SHOW=$(perl -CSA -Mutf8 -e '$_ = shift; print length > 16 ? substr($_, 0, 15) . "…" : $_' "${NAME_SHOWN:-on}")
if [ -n "$IP" ]; then anim_label wifi "$SHOW" label.color=$TEXT
else anim_label wifi "off" label.color=$ERR; fi
[ -n "$SB_BOOT" ] && exit 0

# ── Popup ─────────────────────────────────────────────────────────────────────
W=$POPUP_W_DEFAULT; VW=$(( W - POPUP_KEY_W - POPUP_PAD )); G_WIFI=$'\xf3\xb0\x96\xa9'
SC="$SBD_CACHE/wifiscan.txt"; BUSY="$SBD_CACHE/wifiscan.busy"
SAVED=$(networksetup -listpreferredwirelessnetworks "$IF" 2>/dev/null | tail -n +2 | sed 's/^[[:space:]]*//')
SCST=$(head -1 "$SC" 2>/dev/null)
# Saved networks that the last scan saw: current first, then strongest, at most 4.
NETS=$(awk -F'\t' -v cur="$SSID" 'NR == FNR { if ($0 != "") saved[$0] = 1; next }
  FNR > 1 && ($1 in saved) { printf "%d\t%s\t%d\n", ($1 == cur ? 0 : 1), $1, $2 }' <(printf '%s\n' "$SAVED") "$SC" 2>/dev/null \
  | sort -t$'\t' -k1,1n -k3,3nr | head -4 | cut -f2,3)
glyph() {   # RSSI -> signal glyph, 4 levels
  if [ "$1" -ge -55 ]; then printf '\xf3\xb0\xa4\xa8'; elif [ "$1" -ge -65 ]; then printf '\xf3\xb0\xa4\xa5'
  elif [ "$1" -ge -75 ]; then printf '\xf3\xb0\xa4\xa2'; else printf '\xf3\xb0\xa4\x9f'; fi
}
SSID_ROW=${SSID:-—}; [ -n "$SSID" ] && ! flag_on "$SHOW_WIFI_NAME" && SSID_ROW=hidden
{ printf 'ssid\t%s\t%s\t\nip\t%s\t%s\t\nrouter\t%s\t%s\t\n' "$SSID_ROW" "$TEXT" "${IP:-—}" "$TEXT" \
    "$(ipconfig getoption "$IF" router 2>/dev/null || echo —)" "$TEXT"
  printf '_\tNETWORKS\t%s\t\n' "$TEXT3"
  k=0
  if [ "$SCST" = denied ]; then k=1; printf '_\tLocation access needed ↗\t%s\topen "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"\n' "$TEXT3"
  elif [ -z "$NETS" ] && [ -f "$BUSY" ]; then k=1; printf '_\tScanning …\t%s\t\n' "$TEXT3"
  elif [ -z "$NETS" ]; then k=1; printf '_\tNo saved networks nearby\t%s\t\n' "$TEXT3"
  else
    while IFS=$'\t' read -r n r; do
      [ -z "$n" ] && continue; k=$((k + 1))
      if [ -n "$SSID" ] && [ "$n" = "$SSID" ]; then printf '%s\t%s\t%s\t\n' "$(glyph "$r")" "$n" "$TEXT"
      else printf '%s\t%s\t%s\t@/bin/bash %q %d %q\n' "$(glyph "$r")" "$n" "$TEXT2" "$SBD_PLUGINS/wifi_join.sh" $(( k + 3 )) "$n"; fi
    done <<<"$NETS"
  fi
  for ((; k < 4; k++)); do printf '_\t.\t%s\t\n' "$CLEAR"; done   # fixed 4 network rows: popup height does not change between states
  printf 'open\tWi-Fi Settings ↗\t%s\topen "x-apple.systempreferences:com.apple.wifi-settings-extension"\n' "$TEXT2"
} | nbsp2 | POPUP_W=$W popup_rows wifi WI-FI

CUR=$(awk -F'\t' -v s="$SSID" 's != "" && $1 == s {print NR}' <<<"$NETS")
a=(--set wifi.p.0 icon.y_offset=$POPUP_KEY_DY --set wifi.p.1 icon.y_offset=$POPUP_KEY_DY --set wifi.p.2 icon.y_offset=$POPUP_KEY_DY
   --set wifi.p.3 label.font="$FONT_SMALL" background.height=32 label.y_offset=-4 --set wifi.p.8 icon.y_offset=$POPUP_KEY_DY)
for i in 4 5 6 7; do
  a+=(--set wifi.p.$i icon.font="$FONT_ICON" icon.padding_left=13 background.image.drawing=off \
        icon.color=$([ "$(( i - 3 ))" = "${CUR:-0}" ] && echo $TEXT || echo $TEXT3))
done
a+=(--set wifi.p.3 label="NETWORKS$([ -f "$BUSY" ] && [ -n "$NETS" ] && printf '\302\240\302\240…')")
# The check mark of the joined network is a text image: spaces move it in 7.2pt steps.
PX=()
[ -n "$CUR" ] && popup_right "wifi.p.$(( CUR + 3 ))" "✓" "$TEXT" "$W"
sketchybar "${a[@]}" "${PX[@]}" 2>/dev/null
