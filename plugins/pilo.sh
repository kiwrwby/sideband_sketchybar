#!/bin/bash
# Pilo button: the state of your Pilo agents as a small pixel face. Shown only while
# the `pilo` CLI answers; never drawn on a Mac without it.
# Data: `pilo api GET /api/agents`, on pilo_change and every 30 s as a safety net.
# Parsing and state ranking live in lib/pilo.py.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
PXD="$SBD_CACHE/px"; STATE="$SBD_CACHE/pilo"; FAILS="$SBD_CACHE/pilo_fail"

# A burst of pilo_change events runs once: only the last survives its 0.15 s wait.
if [ "$SENDER" = pilo_change ]; then
  echo $$ > "$SBD_CACHE/pilo_evt"; sleep 0.15; [ "$(cat "$SBD_CACHE/pilo_evt" 2>/dev/null)" = $$ ] || exit 0
fi
hide() { rm -f "$FAILS"; echo off > "$STATE"; sbd_stop pilo_anim; sketchybar --set pilo drawing=off --set pilo.ul drawing=off; exit 0; }
# No answer: keep the face for up to 3 failures in a row, so a server restart does not
# make it flicker away. If it was hidden it stays hidden.
miss() {
  local n=$(( $(cat "$FAILS" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAILS"
  [ $n -lt 3 ] && [ "$(cat "$STATE" 2>/dev/null || echo off)" != off ] && exit 0
  hide
}
flag_on "$SHOW_PILO" true || hide
PILO=$(find_cli pilo) || hide
J=$(with_timeout 3 "$PILO" api GET /api/agents 2>/dev/null) || miss
OUT=$(python3 -I "$SBD_ROOT/lib/pilo.py" <<<"$J") || miss
rm -f "$FAILS"
[ -n "$SB_BOOT" ] && { IFS=$'\t' read -r TOP _ <<<"$(head -1 <<<"$OUT")"; echo "$TOP" > "$STATE"; sketchybar --set pilo drawing=on background.image="$PXD/pilo_${TOP}_1.png" --set pilo.ul drawing=on; exit 0; }

IFS=$'\t' read -r TOP NB <<<"$(head -1 <<<"$OUT")"
[ "$(cat "$STATE" 2>/dev/null)" = "$TOP" ] || { echo "$TOP" > "$STATE"; sketchybar --set pilo background.image="$PXD/pilo_${TOP}_1.png"; }
sketchybar --set pilo drawing=on --set pilo.ul drawing=on
flag_on "$PILO_ANIMATE" && ! sbd_reduce_motion && sbd_ensure pilo_anim /bin/bash "$SBD_PLUGINS/pilo_anim.sh"

# Popup: face, name, one line per agent, in the state colour. A click opens the
# dashboard (inbox when something waits on you, agents otherwise).
PORT=$(cat "${PILO_HOME:-$HOME}/.pilo/port" 2>/dev/null || echo 48888)
scol() { case "$1" in blocked|stalled) echo $WARN ;; failed|gaveUp) echo $ERR ;; running) echo $TEXT ;; *) echo $TEXT3 ;; esac; }
i=0; a=(); rows=""; sts=""
while IFS=$'\t' read -r name text st; do
  [ -z "$name" ] && continue
  tab=agents; [ "$st" = blocked ] && tab=inbox
  rows+="$name"$'\t'"$text"$'\t'"$(scol "$st")"$'\t'"open 'http://localhost:$PORT/#$tab'"$'\n'
  a+=(--set pilo.ul.p.$i background.image="$PXD/pilo_s_${st}_1.png" background.image.scale=0.5 background.image.drawing=on
      background.image.padding_left=$POPUP_PAD icon.padding_left=36 icon.color=$TEXT2)
  sts+="$st"$'\n'; i=$((i + 1))
done <<<"$(tail -n +2 <<<"$OUT")"
printf '%s' "$sts" > "$SBD_CACHE/pilo_rows"   # pilo_anim.sh animates the row faces while the popup is open

# Popup placement: its left edge is the underline's left end. With no room to the right
# the popup grows leftwards instead.
for _ in 1 2 3; do Q=$(sketchybar --query pilo.ul 2>/dev/null); [ -n "$Q" ] && break; sleep 0.1; done
AL=$(jq -r --argjson pw "${PILO_POPUP_W:-500}" --argjson disp "$(sketchybar --query displays 2>/dev/null)" '
  (.bounding_rects | to_entries | .[0]) as $r
  | ($disp[] | select(.["arrangement-id"] == ($r.key | split("-")[1] | tonumber)) | .frame.w) as $w
  | if ($r.value.origin[0] + $pw) > ($w - 5) then "right" else "left" end' <<<"$Q" 2>/dev/null)
[ -n "$AL" ] && a+=(--set pilo.ul popup.align=$AL)
POPUP_XA=("${a[@]}"); printf '%s' "$rows" | nbsp2 | POPUP_KW=137 popup_rows pilo.ul "PILO$([ "${NB:-0}" -gt 0 ] && echo " · $NB waiting")"
