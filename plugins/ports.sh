#!/bin/bash
# Listening TCP ports: servers started under PORTS_ROOT, plus Docker containers and
# Ollama. Each row reads "name · detail". Up to 30 rows; the rest opens in a terminal.
# The bar item is the icon only. Every 15 s.
. "${0%/*}/../lib/env.sh"; . "$SBD_ROOT/lib/popup.sh"
flag_on "$SHOW_PORTS" || exit 0
ALL="$SBD_CACHE/ports.all"

RAW=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {n=split($9,a,":"); print $2 "\t" $1 "\t" a[n]}' | sort -u)
PIDS=$(cut -f1 <<<"$RAW" | sort -u | paste -sd, -)
CWDS=$([ -n "$PIDS" ] && lsof -a -d cwd -p "$PIDS" -Fpn 2>/dev/null | awk '/^p/{p=substr($0,2)} /^n/{print p "\t" substr($0,2)}')

# Container names and Ollama models are slow to ask for: refresh once a minute.
DC="$SBD_CACHE/ports.docker"; OC="$SBD_CACHE/ports.ollama"
if [ -z "$(find "$DC" -mmin -1 2>/dev/null)" ]; then
  DK=$(find_cli docker)
  { [ -n "$DK" ] && with_timeout 5 "$DK" ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null | while IFS=$'\t' read -r nm ps; do
      tr ',' '\n' <<<"$ps" | sed -n 's/.*:\([0-9]*\)->.*/\1/p' | sort -u | while read -r hp; do printf '%s\t%s\n' "$hp" "$nm"; done
    done; } > "$DC"
  OL=$(find_cli ollama)
  { [ -n "$OL" ] && with_timeout 5 "$OL" ps 2>/dev/null | awk 'NR>1{print $1}' | paste -sd, -; } > "$OC"
fi
DOCK=$(cat "$DC" 2>/dev/null); OLL=$(cat "$OC" 2>/dev/null)

LIST=$(while IFS=$'\t' read -r pid proc port; do
  [ -z "$pid" ] && continue
  c=$(awk -F'\t' -v p="$port" '$1==p{print $2; exit}' <<<"$DOCK")
  if [ -n "$c" ]; then printf '%s\t%s · docker\n' "$port" "$c"; continue; fi
  case "$proc" in
    (OrbStack*|com.docker*)  continue ;;                   # the VM's own listeners, no container behind them
    (ollama) printf '%s\tollama · %s\n' "$port" "${OLL:-no model}"; continue ;;
  esac
  cwd=$(awk -F'\t' -v p="$pid" '$1==p{print $2}' <<<"$CWDS")
  case "$cwd" in ("$PORTS_ROOT"/*) ;; (*) continue ;; esac
  top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
  cmd=$(ps -o command= -p "$pid" 2>/dev/null)
  case "$proc" in
    (java) case "$cmd" in (*GradleDaemon*) d="gradle daemon" ;; (*) d=$(awk '{print $NF}' <<<"$cmd"); d="java ${d##*.}" ;; esac ;;
    (node) set -- $cmd; b=${1##*/}; [ "$b" = node ] && d="node ${2##*/}" || d="node $b" ;;   # a process that renamed itself keeps its name
    (*) d="$proc" ;;
  esac
  printf '%s\t%s · %s\n' "$port" "${top##*/}" "$d"
done <<<"$RAW" | sort -t$'\t' -k1,1n -u)
N=$(grep -c . <<<"$LIST")
printf '%s\n' "$LIST" > "$ALL"

MAX=30
{
  head -n $MAX <<<"$LIST" | while IFS=$'\t' read -r port what; do
    [ -n "$port" ] && printf ':%s\t%s  ↗\t%s\topen http://localhost:%s\n' "$port" "$what" "$TEXT" "$port"
  done
  [ "$N" -gt $MAX ] && printf '…\t+%s more · show all ↗\t%s\t%s ports\n' $((N - MAX)) "$TEXT2" "$SBD_PLUGINS/show_list.sh"
} | textfit 260 | popup_rows ports PORTS
