#!/bin/bash
# Calendar popup (the clock's popup). Prebuilt every 10 s and redrawn only on change.
#   Year and month sit in the first row, with a dot at the right end: dim on the
#   current month, bright elsewhere (click to jump back). The ‹ and › rows step months
#   and keep the popup open. Today is [29]. Events cover everything touching the month;
#   multi-day ones read 09.23-09.26. Over 16 events: "+N more".
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
OFF_FILE="$SBD_CACHE/calmonth"
OFF=$(cat "$OFF_FILE" 2>/dev/null || echo 0)
case "$SENDER" in
  cal_step) [ "$CAL_STEP" = 0 ] && OFF=0 || OFF=$((OFF + CAL_STEP)) ;;
  *) [ "$(cat "$POPUP_OPEN" 2>/dev/null)" = clock ] || OFF=0 ;;   # while open, keep the viewed month
esac
echo "$OFF" > "$OFF_FILE"

D=$(mktemp -d "${TMPDIR:-/tmp}/sbd-cal.XXXXXX"); trap 'rm -rf "$D"' EXIT   # one dir per run: a month step cannot mix with the 10 s refresh
STEP="@SENDER=cal_step /bin/bash '$SBD_PLUGINS/calendar.sh'"
SBD_HELPERS="$SBD_HELPERS" SBD_CACHE="$SBD_CACHE" HOLIDAY_CAL="$HOLIDAY_CAL" STEP_CMD="$STEP" \
  TEXT=$TEXT TEXT2=$TEXT2 TEXT3=$TEXT3 ERR=$ERR BLUE=$BLUE \
  python3 "$SBD_ROOT/lib/cal_popup.py" "$OFF" "$D" || exit 0
IFS=$'\t' read -r YM _ < "$D/meta"

# Week and header rows have one colour per cell, which SketchyBar text cannot do.
# Each is drawn as an image of coloured text over the row, and the real text goes
# transparent. Images are cached by content.
a=(); for i in 3 4 5 6 7 8 9; do a+=(--set clock.p.$i background.image.drawing=off); done
for f in "$D"/row[0-9]*; do
  [ -f "$f" ] || continue; i=${f##*row}
  png="$SBD_CACHE/calimg-$(md5 -q "$f")-$FONT_SIZE-$(printf '%s' "$FONT_MONO" | md5 -q).png"
  [ -s "$png" ] || SBD_FONT_FAMILY="$FONT_MONO" "$SBD_HELPERS/textspans" "$png" "$FONT_SIZE" < "$f"
  a+=(--set clock.p.$i label.color=$CLEAR background.image="$png" background.image.scale=0.5
      background.image.drawing=on background.image.padding_left=5 background.image.y_offset=-1)
done
DOT=$TEXT3; [ "$OFF" = 0 ] || DOT=$TEXT
YM_PAD=$(printf '%13s%s' '' "$YM" | sed $'s/ /\xc2\xa0/g')
a+=(--set clock.p.0 icon.drawing=on icon="$YM_PAD" icon.color=$TEXT icon.width=0 icon.padding_left=5 icon.padding_right=0
    label.padding_left=3 label.color=$DOT)

# Rows and decoration go out in one command: sent apart, one frame showed in between.
CAL_W=$(( $(perl -e 'print int(35 * $ARGV[0] + 0.999)' "$(sbd_mono_adv)") + 5 + POPUP_PAD + 3 ))
POPUP_XA=("${a[@]}"); POPUP_W=$CAL_W POPUP_KW=98 popup_rows clock CALENDAR < <(nbsp2 < "$D/rows")
sketchybar "${a[@]}" 2>/dev/null   # also when the rows were unchanged and only colours moved
[ "$SENDER" = cal_step ] || /bin/bash "$SBD_PLUGINS/clock.sh"
