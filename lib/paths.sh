#!/bin/bash
# Path resolution only. Sourced by env.sh and by plugins that run every second and
# cannot afford the full bootstrap.
SBD_ROOT="${SBD_ROOT:-$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)}"
SBD_CONFIG="${SIDEBAND_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sideband/config.sh}"
SBD_CACHE="${SIDEBAND_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/sideband}"
SBD_HELPERS="$SBD_ROOT/helpers/bin"
SBD_PLUGINS="$SBD_ROOT/plugins"
