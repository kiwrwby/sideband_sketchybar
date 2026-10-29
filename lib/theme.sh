#!/bin/bash
# Design tokens. The only place colours, radii, spacing, popup geometry and
# animation timing are defined. Everything else reads these variables.
# Sourced by lib/env.sh after the user config.

# ── Palette ───────────────────────────────────────────────────────────────────
# graphite (dark): near-black surfaces, bone-white text, muted teal accent.
# bone (light): the same roles on paper.
sbd_resolve_theme() {
  local t="${THEME:-dark}"
  if [ "$t" = auto ]; then
    t=$(cat "$SBD_CACHE/appearance" 2>/dev/null)
    [ "$t" = light ] || t=dark
  fi
  [ "$t" = light ] || t=dark
  THEME_RESOLVED=$t
}

sbd_resolve_theme
if [ "$THEME_RESOLVED" = light ]; then
  BG=0xfff1efe6        # island
  BG2=0xffe6e3d8       # raised: buttons, active rows
  SURFACE=0xfff6f4ec   # popup
  LINE=0xffcfcbbd      # borders, empty gauge cells
  TEXT=0xff15191a      # values
  TEXT2=0xff555c58     # secondary
  TEXT3=0xff737a74     # captions
  ACCENT_AUTO=0xff2f7a6d
  GREEN=0xff5c7a55
  WARN=0xff8a6a14
  ERR=0xffa8403a
  BLUE=0xff3d6b82   # Saturday; never name a token INFO: SketchyBar passes event data in $INFO
else
  BG=0xff0d0f10
  BG2=0xff171b1c
  SURFACE=0xff111415
  LINE=0xff252b2c
  TEXT=0xffe3dfd2
  TEXT2=0xff9aa09a
  TEXT3=0xff687069
  ACCENT_AUTO=0xff4f9d8f
  GREEN=0xff8aa583
  WARN=0xffc9a65b
  ERR=0xffc4675d
  BLUE=0xff7a9fb3
fi
CLEAR=0x00000000
ACCENT="${ACCENT_COLOR:-auto}"
[ "$ACCENT" = auto ] && ACCENT=$ACCENT_AUTO
# Brand colour of the Claude glyph. Third-party mark, not part of the palette.
BRAND_CLAUDE=0xffd97757

# ── Typography ────────────────────────────────────────────────────────────────
FONT_MONO="${FONT_MONO:-$FONT_FAMILY}"   # fixed-pitch glyphs for grids
FONT_BASE="$FONT_FAMILY:$FONT_STYLE:$FONT_SIZE.0"
FONT_BOLD="$FONT_FAMILY:Bold:$FONT_SIZE.0"
FONT_SMALL="$FONT_FAMILY:$FONT_STYLE:11.0"
FONT_SMALL_BOLD="$FONT_FAMILY:Bold:11.0"
FONT_ICON="$ICON_FONT:Regular:14.0"
FONT_ICON_LARGE="$ICON_FONT:Regular:${AUDIO_ICON_SIZE:-16}.0"
FONT_CLOCK="${CLOCK_FONT_FAMILY:-$FONT_FAMILY}:${CLOCK_FONT_STYLE:-$FONT_STYLE}:${CLOCK_FONT_SIZE:-$FONT_SIZE}.0"

# ── Geometry ──────────────────────────────────────────────────────────────────
# Top inset of the bar. The notch is 38pt tall on current MacBook Pros:
# BAR_TOP + ISLAND_HEIGHT should reach it.
BAR_TOP=5
ISLAND_PAD=11        # inner padding at both ends of an island
BUTTON_SIZE=$ISLAND_HEIGHT      # round buttons: settings, cat, pilo
BUTTON_RADIUS=$(( ISLAND_HEIGHT / 2 ))
CONTROL_RADIUS=3     # small controls inside popups

# ── Popup geometry ────────────────────────────────────────────────────────────
POPUP_ROW_H=24
POPUP_PAD=12         # left/right inner padding
POPUP_KEY_W=64       # width of the caption column
POPUP_W_DEFAULT=261
POPUP_Y=2            # gap between bar and popup
POPUP_RADIUS=4
POPUP_BORDER=1
POPUP_KEY_DY=-1      # captions render 1pt above values in popups; correct it

# ── Motion ────────────────────────────────────────────────────────────────────
ANIM_CURVE=tanh
ANIM_FRAMES=12       # ~0.2s: width changes, space dots

# ── Derived colours ───────────────────────────────────────────────────────────
# Opacity applies to the fill only. Borders stay opaque.
sbd_alpha() { printf '0x%02x%s' $(( ${2:-100} * 255 / 100 )) "${1:4}"; }
ISLAND_FILL=$(sbd_alpha "$BG" "$ISLAND_OPACITY")
POPUP_FILL=$(sbd_alpha "$SURFACE" "$ISLAND_OPACITY")
