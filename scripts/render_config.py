#!/usr/bin/env python3
"""Write the user config: every option, active, with its short hint.

  render_config.py <defaults.sh> [overrides.sh]        > ~/.config/sideband/config.sh
  render_config.py --missing <defaults.sh> <config.sh>   >> config.sh

The result is defaults.sh with the values found in overrides.sh (a sparse config, for
example the output of migrate-config.sh) written in place of the defaults. Nothing needs
uncommenting. --missing leaves an existing config untouched and prints only the options
it does not set yet, under their section headers, to append.
"""
import re
import sys

ASSIGN = re.compile(r"^([A-Z][A-Z0-9_]*)=")
HEADER = "# sideband config. Colours are 0xAARRGGBB, flags are 0 or 1. Apply with: sketchybar --reload"


def blocks(lines):
    """(key, first line index, last line index) of each top-level assignment; arrays span to the closing paren."""
    i = 0
    while i < len(lines):
        m = ASSIGN.match(lines[i])
        if not m:
            i += 1
            continue
        j = i
        if re.search(r"=\(\s*(#.*)?$", lines[i]):
            while j < len(lines) and not re.match(r"^\)", lines[j]):
                j += 1
        yield m.group(1), i, j
        i = j + 1


def main():
    if sys.argv[1] == "--missing":
        defaults = open(sys.argv[2]).read().splitlines()
        have = open(sys.argv[3]).read()
        out, header = [], None
        starts = {i: (k, j) for k, i, j in blocks(defaults)}
        for idx, line in enumerate(defaults):
            if line.startswith("# ──"):
                header = line
            if idx in starts and not re.search(r"^#?\s*%s=" % starts[idx][0], have, re.M):
                if header:
                    out += ["", header]
                    header = None
                out += defaults[idx:starts[idx][1] + 1]
        if out:
            sys.stdout.write("\n".join(out) + "\n")
        return
    defaults = open(sys.argv[1]).read().splitlines()
    over = {}
    if len(sys.argv) > 2:
        text = open(sys.argv[2]).read().splitlines()
        over = {k: text[i:j + 1] for k, i, j in blocks(text)}
    starts = {i: (k, j) for k, i, j in blocks(defaults)}
    out, idx = [HEADER], 0
    while idx < len(defaults):
        if idx in starts:
            key, end = starts[idx]
            out += over.get(key, defaults[idx:end + 1])
            idx = end + 1
            continue
        if idx >= 3 or not (defaults[idx].startswith("#") or not defaults[idx]):   # drop the file's own preamble
            out.append(defaults[idx])
        idx += 1
    sys.stdout.write("\n".join(out).rstrip("\n") + "\n")


if __name__ == "__main__":
    main()
