#!/bin/bash
# Failed GitHub Actions run on the current branch of the shell's working directory.
# Needs gh (brew install gh; gh auth login). SHOW_CI=1 to enable.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
GH=$(find_cli gh)
DIR=$(cat "$SBD_CACHE/cwd" 2>/dev/null)
{ flag_on "$SHOW_CI" && [ -n "$GH" ] && [ -d "$DIR" ] && git -C "$DIR" rev-parse >/dev/null 2>&1; } || { sketchybar --set ci drawing=off; exit 0; }
cd "$DIR" || exit 0
R=$(with_timeout 10 "$GH" run list -L1 --branch "$(git branch --show-current)" --json conclusion,number,url -q '.[0] | "\(.conclusion)\t\(.number)\t\(.url)"' 2>/dev/null)
IFS=$'\t' read -r CONCL NUM URL <<<"$R"
{
  [ -n "$URL" ] && printf 'run\topen last run\t%s\topen '"'"'%s'"'"'\n' "$ERR" "$URL"
  with_timeout 10 "$GH" pr list -L 8 --json number,title,url -q '.[] | "#\(.number)\t\(.title)\t\t open '"'"'\(.url)'"'"'"' 2>/dev/null
} | popup_rows ci CI
if [ "$CONCL" = failure ]; then sketchybar --set ci drawing=on label="ci ✗ #$NUM"; else sketchybar --set ci drawing=off; fi
