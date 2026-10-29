#!/bin/bash
# Space dots for the bar display only. Rebuilds when the space count changes.
#   space ids are global, so the spaces of earlier connected displays are skipped.
#   Detached monitors linger in the spaces preferences: count connected displays only.
. "${0%/*}/../lib/env.sh"
flag_on "$SHOW_SPACES" || exit 0
ME=$(cat "$SBD_CACHE/bar_uuid" 2>/dev/null || echo Main)
CONNECTED=$("$SBD_HELPERS/displays" 2>/dev/null | jq -R . | jq -s -c --arg me "$ME" '. + ["Main", $me]')
read -r S0 N <<<"$(defaults export com.apple.spaces - 2>/dev/null \
  | plutil -extract SpacesDisplayConfiguration."Management Data".Monitors json -o - - 2>/dev/null \
  | jq -r --arg me "$ME" --argjson on "$CONNECTED" '
      reduce .[] as $m ({s0: 0, res: null};
        if .res then .
        elif $m["Display Identifier"] == $me then .res = [.s0, ($m.Spaces | length)]
        elif ($on | index($m["Display Identifier"])) then .s0 += ($m.Spaces | length)
        else . end)
      | .res // empty | "\(.[0]) \(.[1])"' 2>/dev/null)"
[ -n "$N" ] && [ "$N" -gt 0 ] || exit 0
KEY="$SBD_CACHE/spaces.n"
[ "$S0:$N" = "$(cat "$KEY" 2>/dev/null)" ] && exit 0

# Remove by name: regex --remove does not work. Drop the bracket first, removing its
# items first crashes SketchyBar in the bracket size calculation.
old=$(sketchybar --query bar | jq -r '.items[]? | select(test("^space\\.[0-9]+$"))' 2>/dev/null)
sketchybar --remove spaces.seg 2>/dev/null
rm_args=(); for it in $old; do rm_args+=(--remove "$it"); done
[ ${#rm_args[@]} -gt 0 ] && sketchybar "${rm_args[@]}" 2>/dev/null
a=()
for ((i = 1; i <= N; i++)); do
  a+=(--add space space.$i left
      --set space.$i space=$(( S0 + i )) icon.drawing=off label="" label.width=8 \
            background.color=$TEXT3 background.height=8 background.drawing=on \
            padding_right=6 y_offset=0 script="$SBD_PLUGINS/space.sh"
      --move space.$i before space.padr)
done
sketchybar "${a[@]}" \
  --add bracket spaces.seg '/space\..*/' --set spaces.seg background.color=$LINE background.height=$((ISLAND_HEIGHT - 2)) background.drawing=on
echo "$S0:$N" > "$KEY"
sketchybar --trigger space_change   # apply the selected state to the new dots
