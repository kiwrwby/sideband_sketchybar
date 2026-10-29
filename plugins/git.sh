#!/bin/bash
# Directory and branch of the shell. Fed by the shell hook, which sends the shell_cwd
# event with CWD set:
#   sketchybar --trigger shell_cwd CWD="$PWD"   (see README, "Shell hook")
# SHOW_CWD and SHOW_GIT pick what is drawn. Long paths are cut from the left and long
# branch names from the right, so the left island stays bounded (the media island is
# sized for these maxima).
. "${0%/*}/../lib/env.sh"
CWD_FILE="$SBD_CACHE/cwd"
DIR="${CWD:-$(cat "$CWD_FILE" 2>/dev/null)}"
[ -d "$DIR" ] || exit 0
echo "$DIR" > "$CWD_FILE"

if flag_on "$SHOW_CWD"; then
  p="${DIR/#$HOME/~}"
  if [ "${#p}" -gt "$CWD_MAX" ]; then
    tail=${p: -$(( CWD_MAX - 2 ))}
    case "$tail" in */*) tail=${tail#*/} ;; esac   # start on a path boundary
    p="…/$tail"
  fi
  sketchybar --set cwd drawing=on label="$p"
else
  sketchybar --set cwd drawing=off
fi

B=""; flag_on "$SHOW_GIT" && B=$(git -C "$DIR" branch --show-current 2>/dev/null)
if [ -n "$B" ]; then
  [ "${#B}" -gt "$GIT_BRANCH_MAX" ] && B="${B:0:$(( GIT_BRANCH_MAX - 1 ))}…"
  sketchybar --set git drawing=on label="$B"
else
  sketchybar --set git drawing=off
fi
