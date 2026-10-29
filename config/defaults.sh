#!/bin/bash
# sideband defaults. Copied to ~/.config/sideband/config.sh on install; edit that one.
# Colours are 0xAARRGGBB, flags are 0 or 1. Apply with: sketchybar --reload

# ── Theme ─────────────────────────────────────────────────────────────────────
THEME=dark              # dark | light | auto
ACCENT_COLOR=auto       # auto | 0xAARRGGBB
ISLAND_OPACITY=90       # 0-100
POPUP_BLUR=20           # 0 = off

# ── Fonts ─────────────────────────────────────────────────────────────────────
FONT_FAMILY="JetBrains Mono"    # any font, e.g. "SF Pro"
FONT_STYLE=Regular              # Regular | Medium | Bold
FONT_MONO=""                    # calendar grid; empty = FONT_FAMILY. Use "SF Mono" with a proportional font
FONT_SIZE=12
ICON_FONT="JetBrainsMono Nerd Font Propo"

# ── Layout ────────────────────────────────────────────────────────────────────
BAR_DISPLAY=main        # main | display number
ISLAND_HEIGHT=33
ISLAND_RADIUS=12
ISLAND_GAP=5
CELL_GAP=24
CLOCK_CAT_GAP=23
CAT_RIGHT_PAD=16

# ── Wordmark ──────────────────────────────────────────────────────────────────
WORDMARK="sideband"
WORDMARK_PHRASES=(
  "$WORDMARK"
  "tty0"
  "NO CARRIER"
  "login:"
  "carrier lost"
  "local only"
)
WORDMARK_ANIMATE=1
WORDMARK_TYPE_MS=100
WORDMARK_ERASE_MS=45
WORDMARK_HOLD_S=12
WORDMARK_PAUSE_MS=350
WORDMARK_CURSOR=1
WORDMARK_BLINK_MS=530   # 0 = steady

# ── Left island ───────────────────────────────────────────────────────────────
SHOW_CONTROL_CENTER=1
SHOW_SPACES=1
SHOW_FRONT_APP=1
FRONT_APP_MAX=16        # characters
APP_MENU=1              # click the app name for its menus
SHOW_CWD=0              # shell directory, needs the shell hook
SHOW_GIT=1              # git branch, needs the shell hook
CWD_MAX=24              # characters; the path is cut from the left
GIT_BRANCH_MAX=16       # characters
CAL_NEXT=0              # next calendar event
CAL_WINDOW_MIN=60
HOLIDAY_CAL=""          # name of a holiday calendar

# ── Clock ─────────────────────────────────────────────────────────────────────
CLOCK_FORMAT=24         # 24 | 12
CLOCK_AMPM=lower        # lower | upper | off
CLOCK_LEADING_ZERO=0    # 12h only
SHOW_DATE=1
CLOCK_FONT_FAMILY=""    # empty = FONT_FAMILY
CLOCK_FONT_STYLE=""
CLOCK_FONT_SIZE=""

# ── Wi-Fi ─────────────────────────────────────────────────────────────────────
SHOW_WIFI_NAME=1        # 0 hides the network name on the bar and in the popup

# ── Battery ───────────────────────────────────────────────────────────────────
BATTERY_MODE=bar        # bar | percent | hidden
BATTERY_CRITICAL_PCT=20
BATTERY_COLOR_NORMAL=auto       # auto | 0xAARRGGBB
BATTERY_COLOR_CHARGING=auto
BATTERY_COLOR_LOW_POWER=auto
BATTERY_COLOR_CRITICAL=auto

# ── Agents ────────────────────────────────────────────────────────────────────
SHOW_AGENTS=1
SHOW_CLAUDE_AGENT=auto  # auto | 1 | 0
SHOW_CODEX_AGENT=auto
SHOW_GEMINI_AGENT=0     # session count, no quota
SHOW_OPENCODE_AGENT=0   # session count, no quota
AGENT_ORDER=(claude codex gemini opencode)
AGENT_BAR_VALUE=left    # left | used
AGENT_STALE_MIN=180

# ── System menu ───────────────────────────────────────────────────────────────
SYSTEM_MENU=1
CAT_ANIMATE=1

# ── Media island ──────────────────────────────────────────────────────────────
SHOW_MEDIA=0
MEDIA_WIDTH=auto        # auto | points
MEDIA_PROGRESS=1
AUDIO_ICON_SIZE=16

# ── Integrations ──────────────────────────────────────────────────────────────
SHOW_PORTS=0
PORTS_ROOT="$HOME"
SHOW_TAILSCALE=auto     # auto | 1 | 0
SHOW_PILO=auto
PILO_ANIMATE=1
SHOW_DOCKER=auto
SHOW_CI=0
NOTIF_APPS=()           # e.g. ("Slack" "Mail")
TERMINAL_APP="Ghostty"
EDITOR_CMD=""           # empty = $EDITOR, then nano
AUTOMAX=0               # maximize new windows with Rectangle
AUTOMAX_INCLUDE=""
AUTOMAX_EXCLUDE="^(System Settings|Calculator|Finder|Rectangle)$"
