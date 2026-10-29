#!/bin/bash
# sideband installer.
#
#   ./install.sh [options]
#
# Installs sideband for the current user. No root. Safe to run again: every step checks
# before it acts, existing configuration is moved aside (never deleted), and the
# configuration you edit lives in ~/.config/sideband/config.sh, which is never overwritten.
#
# Options
#   --dry-run             print every action, change nothing
#   --migrate             convert the config.sh of an existing SketchyBar setup
#                         (sketchybar-island or an older sideband) into ~/.config/sideband/config.sh
#   --no-service          do not start or restart SketchyBar; run `sketchybar --reload` yourself
#   --no-zapmenu          do not install or start zapmenu
#   --no-fonts            do not install JetBrains Mono / its Nerd Font
#   --with-media          also install media-control (needed for SHOW_MEDIA=1, except Apple Music)
#   --patched-sketchybar  on macOS 27, replace an upstream SketchyBar with the patched build
#   --link                symlink the install directory to this checkout instead of copying it
#   -y, --yes             answer yes to questions (taps, downloads, replacing SketchyBar)
#   -h, --help            this text
#
# Environment
#   SIDEBAND_PREFIX       install directory, default ~/.local/share/sideband
#   SIDEBAND_ZAPMENU_FILE use this local zapmenu tarball instead of downloading (checksum still verified)
#
# Bash 3.2 compatible: this runs on a stock macOS.

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1
[ -f "$SRC/sketchybarrc" ] && [ -f "$SRC/lib/env.sh" ] || { echo "install.sh must sit in a sideband checkout" >&2; exit 1; }
VERSION=$(cat "$SRC/VERSION" 2>/dev/null || echo dev)

# ── Pinned sources ────────────────────────────────────────────────────────────
# SketchyBar 2.24.1 is the latest upstream release. On macOS 27.2 a window owned by
# MenuBarAgent covers the bar and swallows clicks (FelixKratz/SketchyBar#852, still
# open). The tap below builds a fork pinned to one commit with a pinned sha256.
UPSTREAM_FORMULA="felixkratz/formulae/sketchybar"
PATCHED_TAP="strayer/tap"
PATCHED_FORMULA="strayer/tap/sketchybar"
PATCHED_VERSION="2.24.1-fix852.3"
# zapmenu (https://github.com/kaynetik/zapmenu, MIT): keeps the cursor out of the top
# 4px so the auto-hidden macOS menu bar does not drop down over the bar.
ZAPMENU_VERSION="1.2.0"
ZAPMENU_URL="https://github.com/kaynetik/zapmenu/releases/download/v$ZAPMENU_VERSION"
ZAPMENU_SHA256_ARM64="699f1eaa25ba060bed362c603b117b88b4a7c44cf290c74a35a76c0580457093"
ZAPMENU_SHA256_X86_64="080dcfff8ca27818de4a7358e949917a5e81672b82cfadfadb90e11006decca1"

# ── Options ───────────────────────────────────────────────────────────────────
DRY=0; MIGRATE=0; SERVICE=1; ZAPMENU=1; FONTS=1; MEDIA=0; SWITCH_SB=0; LINK=0; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --migrate) MIGRATE=1 ;;
    --no-service) SERVICE=0 ;;
    --no-zapmenu) ZAPMENU=0 ;;
    --no-fonts) FONTS=0 ;;
    --with-media) MEDIA=1 ;;
    --patched-sketchybar) SWITCH_SB=1 ;;
    --link) LINK=1 ;;
    -y|--yes) YES=1 ;;
    -h|--help) sed -n '2,/^# Bash 3.2/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

# ── Output ────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then B=$'\033[1m'; R=$'\033[0m'; RED=$'\033[31m'; YEL=$'\033[33m'; else B=; R=; RED=; YEL=; fi
step() { printf '\n%s== %s%s\n' "$B" "$*" "$R"; }
say()  { printf '   %s\n' "$*"; }
ok()   { printf '   ok  %s\n' "$*"; }
warn() { printf '   %swarn%s %s\n' "$YEL" "$R" "$*" >&2; WARNED=1; }
die()  { printf '%serror%s %s\n' "$RED" "$R" "$*" >&2; exit 1; }
WARNED=0
run() {   # every command that changes the system goes through here
  if [ $DRY = 1 ]; then printf '   + %s\n' "$*"; return 0; fi
  "$@"
}
ask() {   # <question>: yes with --yes, no without a terminal
  [ $YES = 1 ] && return 0
  [ -t 0 ] || { say "$1 -> no (not a terminal; use --yes)"; return 1; }
  local a; printf '   %s [y/N] ' "$1"; read -r a; case "$a" in y|Y|yes) return 0 ;; *) return 1 ;; esac
}

[ "$(id -u)" = 0 ] && die "do not run the installer as root"
[ "$(uname -s)" = Darwin ] || die "sideband runs on macOS only"
[ $DRY = 1 ] && say "dry run: nothing will be changed"

# ── Paths ─────────────────────────────────────────────────────────────────────
PREFIX="${SIDEBAND_PREFIX:-$HOME/.local/share/sideband}"
CONF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
USER_CONFIG="$CONF_HOME/sideband/config.sh"
SB_DIR="$CONF_HOME/sketchybar"           # SketchyBar reads its rc from here
STATE_DIR="$HOME/.local/state/sideband"
STATE="$STATE_DIR/install.env"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/sideband"
TS=$(date +%Y%m%d-%H%M%S)
UID_=$(id -u)

# ── 1. System ─────────────────────────────────────────────────────────────────
step "System"
OS_VER=$(sw_vers -productVersion); OS_MAJOR=${OS_VER%%.*}; ARCH=$(uname -m)
say "macOS $OS_VER, $ARCH"
[ "$OS_MAJOR" -ge 14 ] 2>/dev/null || die "macOS 14 or newer is required (EventKit full-access API)"
case "$ARCH" in arm64|x86_64) ;; *) die "unsupported CPU: $ARCH" ;; esac

if ! xcode-select -p >/dev/null 2>&1 || ! command -v swiftc >/dev/null 2>&1; then
  die "Xcode Command Line Tools are missing. Run: xcode-select --install   then run this installer again"
fi
ok "Xcode Command Line Tools ($(swiftc --version 2>&1 | head -1 | sed 's/(.*//'))"

for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && ! command -v brew >/dev/null 2>&1 && PATH="${b%/brew}:$PATH"; done
command -v brew >/dev/null 2>&1 || die "Homebrew is missing. Install it from https://brew.sh (read the script before you run it), then run this installer again"
ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"
[ -x /usr/bin/python3 ] || die "/usr/bin/python3 is missing (comes with the Command Line Tools)"

brew_has() { brew list --formula --versions "$1" >/dev/null 2>&1; }
cask_has() { brew list --cask --versions "$1" >/dev/null 2>&1; }

# ── 2. SketchyBar ─────────────────────────────────────────────────────────────
step "SketchyBar"
SB_BIN=$(command -v sketchybar || true)
SB_CELLAR="$(brew --cellar 2>/dev/null)/sketchybar"
SB_INST=""; [ -d "$SB_CELLAR" ] && SB_INST=$(ls "$SB_CELLAR" 2>/dev/null | sort | tail -1)
SB_PATCHED=0; case "$SB_INST" in *fix852*) SB_PATCHED=1 ;; esac
SB_FORMULA=$UPSTREAM_FORMULA; [ $SB_PATCHED = 1 ] && SB_FORMULA=$PATCHED_FORMULA

trust_tap() {
  brew tap | grep -qx "$PATCHED_TAP" || run brew tap "$PATCHED_TAP" || return 1
  # Homebrew 7 refuses to load formulae from taps you have not trusted.
  if brew trust --help >/dev/null 2>&1 && ! brew trust --json=v1 2>/dev/null | grep -q "\"$PATCHED_TAP\""; then
    ask "Trust the Homebrew tap $PATCHED_TAP? It builds the patched SketchyBar from one pinned commit." || return 1
    run brew trust --tap "$PATCHED_TAP" || return 1
  fi
}
install_patched() {
  trust_tap || die "the patched SketchyBar needs the tap $PATCHED_TAP: run: brew tap $PATCHED_TAP && brew trust --tap $PATCHED_TAP"
  if [ $DRY = 0 ]; then
    have=$(brew info --json=v2 "$PATCHED_FORMULA" 2>/dev/null | jq -r '.formulae[0].versions.stable // empty')
    if [ "$have" != "$PATCHED_VERSION" ]; then
      warn "the tap now offers SketchyBar $have; this installer was tested with $PATCHED_VERSION"
      ask "Install $have anyway?" || die "aborted"
    fi
  fi
  run brew install "$PATCHED_FORMULA" || die "brew install $PATCHED_FORMULA failed"
}

if [ -z "$SB_INST" ] && [ -z "$SB_BIN" ]; then
  if [ "$OS_MAJOR" -ge 27 ]; then
    say "macOS $OS_MAJOR: installing the patched build ($PATCHED_VERSION) for FelixKratz/SketchyBar#852."
    say "Upstream 2.24.1 loses clicks to the MenuBarAgent window on macOS 27.2."
    say "Revert later with: brew uninstall sketchybar && brew install $UPSTREAM_FORMULA"
    ask "Install $PATCHED_FORMULA?" || die "SketchyBar is required. Install it yourself and run this installer again"
    install_patched
  else
    say "installing upstream SketchyBar"
    run brew tap felixkratz/formulae >/dev/null 2>&1
    run brew install "$UPSTREAM_FORMULA" || die "brew install $UPSTREAM_FORMULA failed"
  fi
elif [ "$OS_MAJOR" -ge 27 ] && [ $SB_PATCHED = 0 ]; then
  if [ $SWITCH_SB = 1 ]; then
    say "replacing upstream SketchyBar $SB_INST with the patched build"
    ask "Replace it? Your SketchyBar config is not touched; the service restarts." || die "aborted"
    run launchctl bootout "gui/$UID_/sh.brew.sketchybar" 2>/dev/null
    run brew uninstall sketchybar || die "could not uninstall sketchybar"
    install_patched
  else
    warn "upstream SketchyBar $SB_INST on macOS $OS_MAJOR: clicks on the bar may be swallowed (SketchyBar#852)."
    say "Switch to the patched build with: ./install.sh --patched-sketchybar"
    say "Revert later with: brew uninstall sketchybar && brew install $UPSTREAM_FORMULA"
  fi
else
  ok "SketchyBar ${SB_INST:-present}$([ $SB_PATCHED = 1 ] && echo ' (patched build for #852; left as is)')"
fi
SB_BIN=$(command -v sketchybar || echo /opt/homebrew/bin/sketchybar)

# ── 3. Other dependencies ─────────────────────────────────────────────────────
step "Dependencies"
if command -v jq >/dev/null 2>&1; then ok "jq"; else run brew install jq || die "could not install jq"; fi

if [ $FONTS = 1 ]; then
  have_font() { ls "$HOME/Library/Fonts" /Library/Fonts 2>/dev/null | grep -qi "$1"; }
  need=""
  have_font 'JetBrainsMono-Regular' || cask_has font-jetbrains-mono || need="$need font-jetbrains-mono"
  have_font 'JetBrainsMonoNerdFont' || cask_has font-jetbrains-mono-nerd-font || need="$need font-jetbrains-mono-nerd-font"
  if [ -n "$need" ]; then
    say "fonts (not bundled, installed from Homebrew casks):$need"
    # shellcheck disable=SC2086
    run brew install --cask $need || warn "font install failed; set FONT_FAMILY/ICON_FONT to fonts you have"
  else ok "JetBrains Mono and its Nerd Font"; fi
fi

if [ $MEDIA = 1 ]; then
  if brew_has media-control; then ok "media-control"; else run brew install media-control || warn "media-control install failed"; fi
fi

# ── 4. zapmenu ────────────────────────────────────────────────────────────────
ZAP_BIN=""; ZAP_PLIST=""; ZAP_BY_US=0
if [ $ZAPMENU = 1 ]; then
  step "zapmenu (keeps the auto-hidden macOS menu bar from dropping over the bar)"
  for p in "$(command -v zapmenu 2>/dev/null)" "$HOME/.local/bin/zapmenu" /opt/homebrew/bin/zapmenu /usr/local/bin/zapmenu; do
    [ -n "$p" ] && [ -x "$p" ] && { ZAP_BIN=$p; break; }
  done
  if [ -n "$ZAP_BIN" ]; then
    ok "found $ZAP_BIN"
  else
    case "$ARCH" in arm64) ZA=aarch64; ZSHA=$ZAPMENU_SHA256_ARM64 ;; *) ZA=x86_64; ZSHA=$ZAPMENU_SHA256_X86_64 ;; esac
    ZNAME="zapmenu-v$ZAPMENU_VERSION-$ZA-macos.tar.gz"
    if ask "Download $ZNAME from github.com/kaynetik/zapmenu and verify its sha256?"; then
      if [ $DRY = 1 ]; then
        say "+ curl -fsSL $ZAPMENU_URL/$ZNAME, verify sha256 $ZSHA, install to ~/.local/bin/zapmenu"
      else
        ZT=$(mktemp -d "${TMPDIR:-/tmp}/sideband-zap.XXXXXX")
        if [ -n "${SIDEBAND_ZAPMENU_FILE:-}" ]; then cp "$SIDEBAND_ZAPMENU_FILE" "$ZT/$ZNAME"
        else curl -fsSL --max-time 60 -o "$ZT/$ZNAME" "$ZAPMENU_URL/$ZNAME" || { rm -rf "$ZT"; die "download failed: $ZAPMENU_URL/$ZNAME"; }; fi
        got=$(shasum -a 256 "$ZT/$ZNAME" | awk '{print $1}')
        [ "$got" = "$ZSHA" ] || { rm -rf "$ZT"; die "zapmenu checksum mismatch (got $got, expected $ZSHA). Nothing was installed"; }
        mkdir -p "$ZT/x" && tar -xzf "$ZT/$ZNAME" -C "$ZT/x" || { rm -rf "$ZT"; die "could not unpack $ZNAME"; }
        [ -f "$ZT/x/zapmenu" ] || { rm -rf "$ZT"; die "archive does not contain zapmenu"; }
        mkdir -p "$HOME/.local/bin" && install -m 755 "$ZT/x/zapmenu" "$HOME/.local/bin/zapmenu"
        rm -rf "$ZT"; ZAP_BIN="$HOME/.local/bin/zapmenu"; ZAP_BY_US=1
        ok "installed $ZAP_BIN ($got)"
      fi
    else
      say "skipped. Install it yourself from https://github.com/kaynetik/zapmenu/releases or pass --no-zapmenu"
    fi
  fi
  # LaunchAgent: reuse an existing one, never create a second.
  if [ -n "$ZAP_BIN" ] || [ $DRY = 1 ]; then
    existing=$(grep -l '/zapmenu' "$HOME"/Library/LaunchAgents/*.plist 2>/dev/null | head -1)
    if [ -n "$existing" ]; then
      ok "LaunchAgent exists: ${existing##*/} (not touched)"
    elif launchctl list 2>/dev/null | grep -qi zapmenu; then
      ok "a zapmenu job is already loaded (not touched)"
    else
      ZAP_PLIST="$HOME/Library/LaunchAgents/local.sideband.zapmenu.plist"
      if [ $DRY = 1 ]; then say "+ write $ZAP_PLIST and bootstrap it"
      else
        mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs/sideband"
        cat > "$ZAP_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.sideband.zapmenu</string>
  <key>ProgramArguments</key><array><string>$ZAP_BIN</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/sideband/zapmenu.log</string>
</dict></plist>
PLIST
        launchctl bootstrap "gui/$UID_" "$ZAP_PLIST" 2>/dev/null || warn "could not load $ZAP_PLIST; log out and in, or run: launchctl bootstrap gui/$UID_ $ZAP_PLIST"
        ok "LaunchAgent local.sideband.zapmenu"
      fi
    fi
  fi
fi

# ── 5. Files ──────────────────────────────────────────────────────────────────
step "Files"
if [ $LINK = 1 ]; then
  if [ -L "$PREFIX" ] && [ "$(readlink "$PREFIX")" = "$SRC" ]; then ok "$PREFIX -> $SRC"
  else
    [ -e "$PREFIX" ] && [ ! -L "$PREFIX" ] && { run mv "$PREFIX" "$PREFIX.bak.$TS"; say "moved the old install to $PREFIX.bak.$TS"; }
    run mkdir -p "${PREFIX%/*}"; run ln -sfn "$SRC" "$PREFIX"; ok "$PREFIX -> $SRC"
  fi
else
  [ -L "$PREFIX" ] && run rm "$PREFIX"   # a link from an earlier --link install
  [ "$(cd "$SRC" && pwd -P)" = "$(cd "$PREFIX" 2>/dev/null && pwd -P)" ] && die "run the installer from your checkout, not from $PREFIX"
  # rsync --delete below removes whatever is not in the checkout, so refuse a directory
  # that is neither empty, nor ours (marker, or the files an earlier version left).
  if [ -d "$PREFIX" ] && [ -n "$(ls -A "$PREFIX" 2>/dev/null)" ] && [ ! -f "$PREFIX/.sideband-install" ] \
     && ! { [ -f "$PREFIX/sketchybarrc" ] && [ -f "$PREFIX/lib/env.sh" ]; }; then
    die "$PREFIX exists, is not empty and does not look like a sideband install. Pick another SIDEBAND_PREFIX"
  fi
  run mkdir -p "$PREFIX"
  # Copy the tree. Binaries already built in this checkout come along (mtimes are kept,
  # so build.sh below only recompiles what is out of date); a fresh clone has none.
  run rsync -a --delete --exclude '.git' --exclude '.DS_Store' --exclude '.sideband-install' "$SRC/" "$PREFIX/" \
    || die "could not copy files to $PREFIX"
  [ $DRY = 1 ] || printf 'sideband %s\n' "$VERSION" > "$PREFIX/.sideband-install"
  ok "$PREFIX"
fi

say "compiling Swift helpers"
if [ $DRY = 1 ]; then say "+ $PREFIX/helpers/build.sh"
else
  /bin/bash "$PREFIX/helpers/build.sh" >/dev/null 2>"${TMPDIR:-/tmp}/sideband-build.log" \
    || { cat "${TMPDIR:-/tmp}/sideband-build.log" >&2; die "helper build failed"; }
  ok "helpers built ($(ls "$PREFIX/helpers/bin" | wc -l | tr -d ' ') items)"
fi
if [ $DRY = 0 ]; then
  chmod +x "$PREFIX/sketchybarrc" "$PREFIX"/plugins/*.sh "$PREFIX"/scripts/*.sh "$PREFIX/install.sh" "$PREFIX/uninstall.sh" 2>/dev/null
fi

# ── 6. SketchyBar config directory ────────────────────────────────────────────
step "SketchyBar configuration"
BACKUP=""
# Old scripts keep running after their files move. Stop anything started from the old layout.
legacy_stop() {
  # Anchored at the start of the command line: an editor with one of these files open is not ours.
  local d; d=$(printf '%s' "$SB_DIR" | sed 's/[][\.*^$+?(){}|]/\\&/g')
  pkill -f "^(/bin/bash |bash )?$d/plugins/" 2>/dev/null; pkill -f "^$d/helper/audio " 2>/dev/null; pkill -x clickaway 2>/dev/null
  return 0
}
if [ -e "$SB_DIR" ] || [ -L "$SB_DIR" ]; then
  if [ -f "$SB_DIR/.sideband-managed" ]; then ok "managed by sideband already; refreshing the stub"
  else
    BACKUP="$CONF_HOME/sketchybar.bak.$TS"
    say "existing SketchyBar config found"
    [ $DRY = 1 ] || legacy_stop
    run mv "$SB_DIR" "$BACKUP" || die "could not move $SB_DIR"
    ok "moved to $BACKUP (restore with ./uninstall.sh --restore)"
  fi
fi
run mkdir -p "$SB_DIR"
if [ $DRY = 1 ]; then say "+ write $SB_DIR/sketchybarrc (stub) and .sideband-managed"
else
  cat > "$SB_DIR/sketchybarrc" <<STUB
#!/bin/bash
# Managed by sideband. Do not edit: the real configuration is ~/.config/sideband/config.sh
# and the code lives in $PREFIX. Remove with ./uninstall.sh.
exec "$PREFIX/sketchybarrc" "\$@"
STUB
  chmod +x "$SB_DIR/sketchybarrc"
  printf 'sideband %s\n' "$VERSION" > "$SB_DIR/.sideband-managed"
  ok "$SB_DIR/sketchybarrc -> $PREFIX/sketchybarrc"
fi

# ── 7. User config ────────────────────────────────────────────────────────────
step "User configuration"
if [ -e "$USER_CONFIG" ]; then
  ok "$USER_CONFIG exists (never overwritten)"
else
  run mkdir -p "${USER_CONFIG%/*}"
  OLDCFG=""
  # In a dry run nothing has been moved yet, so the old config is still where it was.
  [ $MIGRATE = 1 ] && for c in "$BACKUP/config.sh" "$SB_DIR/config.sh" "$CONF_HOME/sketchybar.backup/config.sh"; do [ -f "$c" ] && { OLDCFG=$c; break; }; done
  RENDER="/usr/bin/python3 -I $SRC/scripts/render_config.py $SRC/config/defaults.sh"
  if [ -n "$OLDCFG" ]; then
    say "migrating $OLDCFG"
    if [ $DRY = 1 ]; then say "+ scripts/migrate-config.sh $OLDCFG, rendered with every option into $USER_CONFIG"
    else
      /bin/bash "$SRC/scripts/migrate-config.sh" "$OLDCFG" > "$USER_CONFIG.sparse" || die "migration failed"
      $RENDER "$USER_CONFIG.sparse" > "$USER_CONFIG" || die "could not write $USER_CONFIG"
      rm -f "$USER_CONFIG.sparse"; ok "wrote $USER_CONFIG"
    fi
  else
    [ $MIGRATE = 1 ] && say "nothing to migrate (no earlier config.sh found); starting with defaults"
    if [ $DRY = 1 ]; then say "+ write $USER_CONFIG with every option listed"
    else $RENDER > "$USER_CONFIG" || die "could not write $USER_CONFIG"; ok "wrote $USER_CONFIG"; fi
  fi
fi
if [ $DRY = 0 ]; then
  /bin/bash -n "$USER_CONFIG" || die "$USER_CONFIG has a syntax error"
fi

# ── 8. State record (read by uninstall.sh) ────────────────────────────────────
if [ $DRY = 0 ]; then
  mkdir -p "$STATE_DIR"
  prev() { grep "^$1=" "$STATE" 2>/dev/null | tail -1 | cut -d= -f2-; }   # keep what an earlier run recorded
  OLD_BACKUP=$(prev BACKUP); OLD_ZPLIST=$(prev ZAP_PLIST); OLD_ZBIN=$(prev ZAP_BIN_BY_US)
  {
    echo "PREFIX=$PREFIX"; echo "VERSION=$VERSION"; echo "INSTALLED_AT=$TS"
    echo "BACKUP=${BACKUP:-$OLD_BACKUP}"
    echo "ZAP_PLIST=${ZAP_PLIST:-$OLD_ZPLIST}"
    [ $ZAP_BY_US = 1 ] && echo "ZAP_BIN_BY_US=$ZAP_BIN" || echo "ZAP_BIN_BY_US=$OLD_ZBIN"
  } > "$STATE.new" && mv "$STATE.new" "$STATE"
fi

# ── 9. Service ────────────────────────────────────────────────────────────────
step "Service"
SB_LABEL=$(launchctl list 2>/dev/null | awk '/sketchybar/ {print $3; exit}')
SB_PLIST=$(ls "$HOME"/Library/LaunchAgents/*sketchybar*.plist 2>/dev/null | head -1)
if [ $SERVICE = 0 ]; then
  say "--no-service: not touching the running SketchyBar. Apply with: sketchybar --reload"
else
  if [ -n "$SB_LABEL" ]; then
    say "launchd job $SB_LABEL exists; restarting it (no second agent is created)"
    [ $DRY = 1 ] || legacy_stop
    run launchctl kickstart -k "gui/$UID_/$SB_LABEL" || warn "could not restart $SB_LABEL"
  elif [ -n "$SB_PLIST" ]; then
    # Installed but not loaded (for example after `launchctl bootout`): load the plist that is already there.
    say "loading the existing agent ${SB_PLIST##*/} (no second agent is created)"
    [ $DRY = 1 ] || legacy_stop
    run launchctl bootstrap "gui/$UID_" "$SB_PLIST" || warn "could not load $SB_PLIST"
  elif pgrep -f '(^|/)sketchybar$' >/dev/null 2>&1; then
    say "a SketchyBar process runs outside launchd: reloading it"
    run "$SB_BIN" --reload
  else
    say "starting SketchyBar at login with brew services"
    run brew services start "$SB_FORMULA" || warn "brew services failed. Start it yourself: brew services start $SB_FORMULA"
  fi
fi

# ── 10. Verify ────────────────────────────────────────────────────────────────
step "Verify"
FAIL=0
chk() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else warn "FAILED: $1"; FAIL=1; fi; }
if [ $DRY = 1 ]; then say "skipped in a dry run"; else
  chk "stub is executable"               "[ -x '$SB_DIR/sketchybarrc' ]"
  chk "sketchybarrc present"             "[ -x '$PREFIX/sketchybarrc' ]"
  chk "helpers built"                    "[ -x '$PREFIX/helpers/bin/notch' ] && [ -x '$PREFIX/helpers/bin/textwidth' ]"
  chk "every script parses (bash 3.2)"   "for f in '$PREFIX'/sketchybarrc '$PREFIX'/lib/*.sh '$PREFIX'/items/*.sh '$PREFIX'/plugins/*.sh; do /bin/bash -n \"\$f\" || exit 1; done"
  chk "python modules compile"           "/usr/bin/python3 -I -m py_compile '$PREFIX'/lib/*.py"
  if [ $SERVICE = 1 ]; then
    n=0; while [ $n -lt 40 ]; do
      [ -f "$CACHE/ready" ] && [ "$(( $(date +%s) - $(stat -f %m "$CACHE/ready") ))" -lt 60 ] && break
      sleep 0.5; n=$((n + 1))
    done
    chk "bar finished loading (ready marker)" "[ -f '$CACHE/ready' ] && [ \$(( \$(date +%s) - \$(stat -f %m '$CACHE/ready') )) -lt 60 ]"
    chk "SketchyBar answers"             "'$SB_BIN' --query bar"
    sleep 1
    servers=$(pgrep -f '(^|/)sketchybar( --config .*)?$' | wc -l | tr -d ' ')
    chk "exactly one SketchyBar server ($servers)" "[ '$servers' = 1 ]"
    wm=$(pgrep -f "$PREFIX/plugins/wordmark.sh" | wc -l | tr -d ' ')
    chk "no duplicate wordmark daemon ($wm)" "[ '$wm' -le 1 ]"
  fi
fi

# ── Manual steps ──────────────────────────────────────────────────────────────
step "What macOS will not let a script do"
cat <<EOF
   1. Hide the native menu bar: System Settings > Control Center >
      "Automatically hide and show the menu bar" > Always.
$([ $ZAPMENU = 1 ] && printf '%s\n' "   2. zapmenu needs \"Device Control and Data Access\" (macOS 27; \"Accessibility\" before)
      and Input Monitoring: System Settings > Privacy & Security. Add
      ${ZAP_BIN:-the zapmenu binary} and switch it on.")
   3. The app-menu popup reads menus through Accessibility: allow sketchybar there.
   4. First use asks for access: Calendar (calendar popup), Location (Wi-Fi network
      names; the helper is $PREFIX/helpers/bin/WifiScan.app).
   5. Open the Settings button on the bar, or edit $USER_CONFIG.
EOF
if [ $DRY = 1 ]; then printf '\ndry run finished, nothing changed.\n'
elif [ $FAIL = 1 ]; then printf '\ninstalled with problems, see above. Logs: %s/sideband-dev.log, ~/.cache/sideband/run/*.log\n' "${TMPDIR:-/tmp}"; exit 1
else printf '\nsideband %s installed.%s\n' "$VERSION" "$([ $WARNED = 1 ] && echo ' Warnings above.')"; fi
