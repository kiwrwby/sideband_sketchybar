#!/bin/bash
# CPU, memory and disk for the system popup and the cat's speed. Every 5 s.
# The cat itself is drawn by cat.sh; this script only writes the numbers it reads.
. "${0%/*}/../lib/env.sh"
CPU=$(ps -A -o %cpu= | awk -v n="$(sysctl -n hw.ncpu)" '{s+=$1} END {printf "%d", s/n}')
MEM=$(memory_pressure | awk '/free percentage/ {printf "%d", 100-$5}')
# Disk: APFS container free space, the number System Settings > Storage shows
# (purgeable space is not counted as free). Cached for 60 s, diskutil is slow.
DF="$SBD_CACHE/disk"
[ -n "$(find "$DF" -mtime -60s 2>/dev/null)" ] || LANG=C diskutil info / | awk -F'[()]' '
  /Container Total Space/ {t=$2+0} /Container Free Space/ {f=$2+0} END {if (t) printf "%.0f %.0f", f/1e9, t/1e9}' > "$DF"
read -r FREE_GB TOTAL_GB < "$DF"

echo "$CPU $MEM" > "$SBD_CACHE/cat"
[ -n "$SB_BOOT" ] && exit 0
cc=$TEXT2; [ "$CPU" -ge 80 ] && cc=$WARN   # popup line is one colour; warn when either is high
[ "$MEM" -ge 80 ] && cc=$WARN
TEXTLINE="CPU ${CPU}%  RAM ${MEM}%  DISK ${FREE_GB:-—}G free"
sketchybar --set sys.stats label="$TEXTLINE" label.color=$cc label.width=$(( $(textw "$TEXTLINE") + 12 )) 2>/dev/null
