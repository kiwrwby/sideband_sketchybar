#!/bin/bash
# Bar display and notch measurement. Sourced by sketchybarrc and by the display
# guard when the display layout changes. Sets DID DX DW DUUID NL NR NOTCH_W and
# writes notch_l, bar_x0 and bar_uuid into the cache.
#   notch_l  right end of the media island: notch left edge - ISLAND_GAP
#   bar_x0   left edge of the bar display in global coordinates
#   bar_uuid lets spaces.sh count only this display's spaces
# Without a notch the display centre stands in for both notch edges.

sbd_measure_display() {
  local q
  q=$(sketchybar --query displays 2>/dev/null)
  read -r DID DX DW DUUID <<<"$(jq -r --arg w "${BAR_DISPLAY:-main}" '
    ((map(select((($w == "main") and (.frame.x == 0 and .frame.y == 0)) or ((.["arrangement-id"] | tostring) == $w))) | .[0]) // .[0])
    | "\(.DirectDisplayID) \(.frame.x | floor) \(.frame.w | floor) \(if .frame.x == 0 and .frame.y == 0 then "Main" else .UUID end)"' <<<"$q" 2>/dev/null)"
  read -r NL NR <<<"$("$SBD_HELPERS/notch" "$DID" 2>/dev/null)"
  NL=${NL:-$(( ${DW:-1800} / 2 ))}
  NR=${NR:-$NL}
  NOTCH_W=$(( NR > NL ? NR - NL : 200 ))
  echo $(( NL - ISLAND_GAP )) > "$SBD_CACHE/notch_l"
  echo "${DX:-0}" > "$SBD_CACHE/bar_x0"
  echo "${DUUID:-Main}" > "$SBD_CACHE/bar_uuid"
}
