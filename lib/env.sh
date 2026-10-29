#!/bin/bash
# Bootstrap. Every script starts with:
#   . "${0%/*}/../lib/env.sh"
# (or the BASH_SOURCE equivalent when sourced from lib/). Resolves paths, loads
# defaults, the user config, the theme and the shared helpers.
# Written for bash 3.2: no associative arrays, no ${var,,}, no mapfile.

. "${BASH_SOURCE[0]%/*}/paths.sh"
# Phrases and app names are cut by character. In a non-UTF-8 locale bash 3.2 counts bytes.
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *UTF-8*|*utf8*) ;; *) export LC_CTYPE=en_US.UTF-8 ;; esac
[ -d "$SBD_CACHE/run" ] || mkdir -p "$SBD_CACHE/run"

# shellcheck source=../config/defaults.sh
. "$SBD_ROOT/config/defaults.sh"
# shellcheck disable=SC1090
[ -r "$SBD_CONFIG" ] && . "$SBD_CONFIG"
. "$SBD_ROOT/lib/theme.sh"
. "$SBD_ROOT/lib/util.sh"
