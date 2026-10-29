#!/bin/bash
# Agent group: Claude Code, Codex CLI, Gemini CLI, OpenCode.
#   agents.sh              every provider, plus the popup. Every 15 s.
#   agents.sh <provider>   one provider's label only. Gemini and OpenCode poll this way.
# All data comes from lib/agents.py. Nothing here knows where a number came from.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
export AGENT_STALE_MIN AGENT_BAR_VALUE

role() { case "$1" in text) echo $TEXT ;; text2) echo $TEXT2 ;; err) echo $ERR ;; warn) echo $WARN ;; *) echo $TEXT3 ;; esac; }
want() {   # provider -> 0 when it should be drawn
  local v
  case $1 in claude) v=$SHOW_CLAUDE_AGENT ;; codex) v=$SHOW_CODEX_AGENT ;; gemini) v=$SHOW_GEMINI_AGENT ;; opencode) v=$SHOW_OPENCODE_AGENT ;; *) return 1 ;; esac
  flag_on "$SHOW_AGENTS" || return 1
  [ "$v" = auto ] && { [ "$2" = 1 ]; return; }
  flag_on "$v"
}
update() {   # provider -> sets label and visibility; leaves DRAWN=1 if shown
  local p=$1 label colour det
  IFS=$'\t' read -r label colour det < <(python3 -I "$SBD_ROOT/lib/agents.py" bar "$p" 2>/dev/null)
  if want "$p" "${det:-0}"; then
    anim_label "agent.$p" "${label:-—}" label.color=$(role "${colour:-text3}") drawing=on
    DRAWN=1
  else
    sketchybar --set "agent.$p" drawing=off
  fi
}

if ! flag_on "$SHOW_AGENTS"; then   # master switch: nothing to read, nothing to draw
  sketchybar --set agent drawing=off --set agent.claude drawing=off --set agent.codex drawing=off \
             --set agent.gemini drawing=off --set agent.opencode drawing=off
  exit 0
fi
if [ -n "$1" ]; then
  DRAWN=0; update "$1"
  exit 0
fi

DRAWN=0
for p in claude codex gemini opencode; do update "$p"; done
sketchybar --set agent drawing=$([ "$DRAWN" = 1 ] && echo on || echo off)
[ -n "$SB_BOOT" ] && exit 0

# ── Popup ─────────────────────────────────────────────────────────────────────
ORDER=$(printf '%s\n' "${AGENT_ORDER[@]}" claude codex gemini opencode | awk '!s[$0]++' | tr '\n' ' ')
SHOWN=""; for p in $ORDER; do want "$p" 1 && SHOWN="$SHOWN $p"; done
ROWS=(); while IFS= read -r l; do [ -n "$l" ] && ROWS+=("$l"); done < <(
  AGENT_TEXT=$TEXT AGENT_TEXT2=$TEXT2 AGENT_TEXT3=$TEXT3 AGENT_ACCENT=$ACCENT AGENT_WARN=$WARN AGENT_ERR=$ERR \
  AGENT_REFRESH="@SENDER=routine NAME=agent /bin/bash '$SBD_PLUGINS/agents.sh'" \
  python3 -I "$SBD_ROOT/lib/agents.py" rows $SHOWN 2>/dev/null)
[ ${#ROWS[@]} -gt 0 ] || ROWS=($'N\t_\tusage data unavailable\t'"$TEXT3"$'\t')

# Fixed 14 rows: a provider appearing or a window expiring never recreates items
# while the popup is open. M rows carry the meter colour in field 5, not a click.
MAXR=14
# The popup is as wide as its longest row: caption column, text, both paddings. Measured
# in the base font (a little wider than the 11pt rows draw), so nothing is cut.
AGENT_W=348
for ((i = 0; i < MAXR && i < ${#ROWS[@]}; i++)); do
  IFS=$'\t' read -r kind key text colour extra <<<"${ROWS[$i]}"
  w=$(( 96 + $(textw "$text") + 2 * POPUP_PAD )); [ $w -gt $AGENT_W ] && AGENT_W=$w
done
{
  for ((i = 0; i < MAXR && i < ${#ROWS[@]}; i++)); do
    IFS=$'\t' read -r kind key text colour extra <<<"${ROWS[$i]}"
    case $kind in M) extra="" ;; esac
    printf '%s\t%s\t%s\t%s\n' "$key" "$text" "$colour" "$extra"
  done
  for ((i = ${#ROWS[@]}; i < MAXR; i++)); do printf '~\t.\t%s\t\n' "$TEXT3"; done
} | POPUP_W=$AGENT_W POPUP_KW=96 popup_rows agent ""

S=()
for ((i = 0; i < MAXR; i++)); do
  kind=Z; extra=""
  [ $i -lt ${#ROWS[@]} ] && IFS=$'\t' read -r kind _ _ _ extra <<<"${ROWS[$i]}"
  case $kind in
    H) S+=(--set agent.p.$i icon.drawing=off label.font="$FONT_SMALL_BOLD" label.color=$TEXT2 label.padding_left=$POPUP_PAD background.height=25 background.color=$CLEAR) ;;
    M) S+=(--set agent.p.$i icon.drawing=on icon.font="Menlo:Regular:11.0" icon.color="${extra:-$TEXT3}" icon.width=96 \
            icon.padding_left=$POPUP_PAD label.font="$FONT_SMALL" label.padding_left=0 background.height=23 background.color=$CLEAR) ;;
    F) S+=(--set agent.p.$i icon.drawing=off label.font="$FONT_SMALL" label.padding_left=$POPUP_PAD background.height=29 background.color=$BG2) ;;
    *) S+=(--set agent.p.$i icon.drawing=off label.font="$FONT_SMALL" label.padding_left=$POPUP_PAD background.height=23 background.color=$CLEAR) ;;
  esac
done
sketchybar "${S[@]}" >/dev/null 2>&1
