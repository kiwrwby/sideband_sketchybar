#!/bin/bash
# Popup engine. Sourced by plugins after lib/env.sh.
#
# Contents are built ahead of time by each item's periodic refresh. A click only
# opens or closes (plugins/popup_click.sh), so popups open instantly.
#
#   popup_rows <parent> <title>      rows on stdin: key<TAB>value<TAB>colour<TAB>click
#     key    caption column. "_" = single-line text row, "~" = hidden padding row,
#            "=" = calendar cell row
#     click  command run on click; the popup closes afterwards. Prefix "@" keeps it open.
#            Empty = row is not clickable.
#   Knobs (set per call): POPUP_W row width, POPUP_KW caption width, POPUP_MAXC value
#   truncation, POPUP_XA extra --set arguments sent in the same command as the rows.
#
# Row counts stay fixed per popup (pad with "~" rows). Rebuilding rows while a
# popup is open makes it vanish, so contents change in place instead.

POPUP_PARENTS="cpu.ul pilo.ul bat agent ports ts docker ci media vol.ul cal wifi clock front_app"
POPUP_OPEN="$SBD_CACHE/popup_open"      # name of the open popup; absent = none open
POPUP_LIB="${BASH_SOURCE[0]}"
CLICKAWAY="$SBD_HELPERS/clickaway"

# Round buttons draw their underline in a separate item. A click makes macOS raise
# the button's window over it, so re-place the underline to restore window order.
popup_raise() { case "$1" in cpu.ul|pilo.ul) sketchybar --move "$1" after "${1%.ul}" 2>/dev/null ;; esac; }
# Item that draws the underline of a popup's parent cell
popup_under() { case "$1" in bat) echo bat.u ;; agent) echo agent.u ;; *) echo "$1" ;; esac; }

popup_close_all() {   # [popup to keep]
  local a=() p u
  # Leaving the calendar rebuilds it for the current month, so the next open starts there.
  if [ "$(cat "$POPUP_OPEN" 2>/dev/null)" = clock ] && [ "$1" != clock ]; then
    rm -f "$POPUP_OPEN"
    ( nohup /bin/bash "$SBD_PLUGINS/calendar.sh" >/dev/null 2>&1 & )
  fi
  for p in $POPUP_PARENTS; do
    [ "$p" = "$1" ] && continue
    a+=(--set "$p" popup.drawing=off)
    for u in $(popup_under "$p"); do a+=(--set "$u" background.drawing=off); done
  done
  [ -z "$1" ] && rm -f "$POPUP_OPEN"
  pkill -x clickaway 2>/dev/null
  sketchybar "${a[@]}" 2>/dev/null
}

popup_toggle() {   # close if open; otherwise close the others and open this one
  if [ "$(cat "$POPUP_OPEN" 2>/dev/null)" = "$1" ]; then popup_close_all; return; fi
  popup_close_all "$1"
  local u b=()
  for u in $(popup_under "$1"); do b+=(--set "$u" background.drawing=on); done
  popup_raise "$1"
  sketchybar --set "$1" popup.drawing=on "${b[@]}"
  echo "$1" > "$POPUP_OPEN"
  [ -x "$CLICKAWAY" ] && ( nohup "$CLICKAWAY" "source '$SBD_ROOT/lib/env.sh'; source '$POPUP_LIB'; popup_close_all" >/dev/null 2>&1 & )
}

popup_rows() {
  local p="$1" title="$2" data n old i=0 k v c click cs a=() it r=()
  data=$(cat)
  [ -n "$SB_BOOT" ] && return 0   # during rc's first pass the bar is off screen; rows are built by the final --update
  n=$(grep -c . <<<"$data")
  old=$(cat "$SBD_CACHE/popup.$p.n" 2>/dev/null || echo -1)
  # Unchanged content is skipped, but only while the rows really exist: a reload, or a
  # batch that failed, can leave the cache claiming rows that are gone. Four fixed pad and
  # title items come with the n rows. POPUP_PREBUILT=1 for popups that build their own items.
  if [ "$title"$'\n'"$data" = "$(cat "$SBD_CACHE/popup.$p" 2>/dev/null)" ]; then
    [ -n "$POPUP_PREBUILT" ] && return 0
    [ "$(sketchybar --query "$p" 2>/dev/null | jq -r '.popup.items | length' 2>/dev/null)" = $((n + 4)) ] && return 0
    old=-1   # rows missing: rebuild
  fi

  if [ "$n" != "$old" ]; then   # row count changed: drop every attached row, then recreate (regex --remove does not work)
    for it in $(sketchybar --query "$p" 2>/dev/null | jq -r '.popup.items[]?' 2>/dev/null); do r+=(--remove "$it"); done
    [ ${#r[@]} -gt 0 ] && sketchybar "${r[@]}" >/dev/null 2>&1
    a+=(--add item "$p.p.a" "popup.$p" --add item "$p.p.t" "popup.$p" --add item "$p.p.g" "popup.$p")
    for ((i = 0; i < n; i++)); do a+=(--add item "$p.p.$i" "popup.$p"); done
    a+=(--add item "$p.p.z" "popup.$p")
  fi

  # Row height is the larger of popup.height and a drawn background, so every row
  # carries a transparent background of POPUP_ROW_H. Padding items are 6pt tall.
  local pad="icon.drawing=off label.drawing=off background.drawing=on background.color=$CLEAR"
  local has_title=off; [ -n "$title" ] && has_title=on
  a+=(--set "$p.p.a" $pad background.height=6 --set "$p.p.z" $pad background.height=6
      --set "$p.p.g" $pad background.height=6 drawing=$has_title)
  a+=(--set "$p.p.t" drawing=$has_title icon="$title" icon.font="$FONT_SMALL_BOLD" icon.color=$TEXT2
      icon.padding_left=$POPUP_PAD icon.padding_right=$POPUP_PAD label.drawing=off
      background.drawing=on background.color=$CLEAR background.height=$POPUP_ROW_H)
  i=0
  # Tabs become 0x1f before reading: with a tab as IFS, `read` merges consecutive tabs
  # and an empty colour field would swallow the click command.
  while IFS=$'\037' read -r k v c click; do
    [ -z "$k$v" ] && continue
    case "$click" in
      "") cs="" ;;
      @*) cs="${click#@}" ;;
      *) cs="$click; source '$SBD_ROOT/lib/env.sh'; source '$POPUP_LIB'; popup_close_all" ;;
    esac
    local lp=0 id=on dr=on mc=${POPUP_MAXC:-0}
    case "$k" in (_) lp=$POPUP_PAD; id=off; mc=0 ;; (=) lp=5; id=off; mc=0 ;; ("~") dr=off ;; esac
    a+=(--set "$p.p.$i" drawing=$dr icon.drawing=$id label.padding_left=$lp label.max_chars=$mc
        ${POPUP_W:+width=$POPUP_W} icon="$k" icon.font="$FONT_BASE" icon.width=${POPUP_KW:-$POPUP_KEY_W}
        icon.padding_left=$POPUP_PAD icon.color=$TEXT3 icon.y_offset=0
        label="$v" label.font="$FONT_BASE" label.color="${c:-$TEXT}" label.padding_right=$POPUP_PAD
        background.drawing=on background.color=$CLEAR background.height=$POPUP_ROW_H background.image.drawing=off
        click_script="$cs")
    i=$((i + 1))
  done < <(tr '\t' '\037' <<<"$data")

  a+=("${POPUP_XA[@]}")
  sketchybar "${a[@]}" >/dev/null 2>&1
  printf '%s\n%s' "$title" "$data" > "$SBD_CACHE/popup.$p"
  echo "$n" > "$SBD_CACHE/popup.$p.n"
}

# Text image for the right edge of a popup row. A row has one text colour, so a
# second colour or exact right alignment is drawn as a background image.
# Appends --set arguments to PX; the caller sends them.
#   popup_right <row item> <text> <colour> [popup width]
popup_right() {
  local f w W=${4:-${POPUP_W:-$POPUP_W_DEFAULT}} dir="$SBD_CACHE/img"
  mkdir -p "$dir"
  f="$dir/$(printf '%s|%s|%s|%s|%s' "$2" "$3" "$FONT_FAMILY" "$FONT_STYLE" "$FONT_SIZE" | md5 | cut -c1-14).png"
  [ -f "$f" ] || SBD_FONT_FAMILY="$FONT_FAMILY" SBD_FONT_STYLE="$FONT_STYLE" "$SBD_HELPERS/textpng" "$2" "$3" "$FONT_SIZE" "$f"
  w=$(img_w "$f")
  PX+=(--set "$1" background.image="$f" background.image.scale=0.5 background.image.drawing=on
       background.image.padding_left=$(( W - POPUP_PAD + 2 - w )) background.image.y_offset=-1)
}

# Change a label and animate its width, so the island does not jump.
#   anim_label <item> <text> [extra --set properties]
anim_label() {
  local it="$1" t="$2" w; shift 2
  w=$(textw "$t")
  if [ -n "$SB_BOOT" ]; then sketchybar --set "$it" label="$t" "$@" label.width=$w; return; fi
  sketchybar --set "$it" label="$t" "$@" --animate $ANIM_CURVE $ANIM_FRAMES --set "$it" label.width=$w
}
