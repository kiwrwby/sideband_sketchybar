# guide

Short answers for the things people actually ask. Setup is in the [README](../README.md).

## first run

Three prompts and one setting, all from macOS:

- **Accessibility** for SketchyBar. Without it the app menu popup stays empty.
- **Calendar** the first time you open the calendar.
- **Location** the first time you open the Wi-Fi popup. macOS hides the network name from apps that lack it. Say no and the bar shows `wifi on` instead of the name.
- **Menu bar**: set it to hide automatically, otherwise the system bar sits on top of this one.

## change things

Press the settings icon. Your editor opens `~/.config/sideband/config.sh`. Save and close, the bar reloads.

```bash
CLOCK_FORMAT=12            # 12-hour clock
CLOCK_AMPM=upper           # AM / PM
BATTERY_MODE=percent       # 87% instead of the bars
SHOW_WIFI_NAME=0           # hide the network name
SHOW_AGENTS=0              # no agent usage at all
SHOW_CODEX_AGENT=0         # just one provider off
AGENT_ORDER=(codex claude gemini opencode)
THEME=auto                 # follow dark / light mode
WORDMARK_PHRASES=("my-mac" "login:" "NO CARRIER")
```

`THEME` takes `dark`, `light` or `auto`. `SHOW_MEDIA=1` adds the media island.

For Apple's look instead of JetBrains Mono:

```bash
FONT_FAMILY="SF Pro"
FONT_MONO="SF Mono"
```

## agent usage

The bar shows how much you have left, not how much you used. `AGENT_BAR_VALUE=used` flips it.

- `—` means the window has reset and nothing newer is known.
- `~38%` means the number is old. It was true then, and only gets lower.
- "reset time unknown" means the source never says when the window resets. sideband does not guess.
- Gemini CLI and OpenCode have no quota. They show how many sessions you ran this week.

Claude's numbers come from the Claude desktop app, Codex's from its session logs. Both are files those apps happen to write. If one changes format, that provider shows `—`.

## media

Turn it on with `SHOW_MEDIA=1`. Apple Music works as is. For everything else (browsers, Spotify) install `media-control`: `brew install media-control`. The progress line appears only when the player reports a length; live streams have none.

## when something is off

Run `bash scripts/doctor.sh`. It checks the install, the service, fonts, permissions and typos in your config, and changes nothing.

- **Clicks do nothing on macOS 27.2.** You are on the unpatched SketchyBar. Run `bash install.sh --patched-sketchybar`. To go back later: `brew uninstall sketchybar && brew install felixkratz/formulae/sketchybar`, once the fix is in a release.
- **The macOS menu bar drops over the bar.** zapmenu is not running or lacks its permission: Privacy & Security, "Device Control and Data Access". `Cmd+Option+B` toggles it.
- **Icons are boxes.** A font is missing: `brew install --cask font-jetbrains-mono font-jetbrains-mono-nerd-font`.
- **No events in the calendar.** Calendar access was denied. Allow it in Privacy & Security.
- **A cell is stale.** `sketchybar --reload`.

## going back

`bash uninstall.sh --restore` removes sideband and puts your previous SketchyBar config back. Your sideband settings stay in `~/.config/sideband` unless you add `--purge-config`.
