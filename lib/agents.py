#!/usr/bin/env python3
"""Agent usage for the bar, from local files only. No network, no tokens, no secrets.

  agents.py data                  JSON for every provider (used by tests)
  agents.py bar <provider>        label<TAB>colour-role<TAB>detected
  agents.py rows <enabled...>     popup rows for the listed providers, in order

Quota (Claude, Codex) is shown only when the provider exposes it:
  Claude  ~/.claude.json cachedUsageUtilization (five_hour, seven_day, with reset
          times), or the Claude desktop app's plan-usage-history.json samples
          (percent only, no reset time). The newer of the two wins.
  Codex   the newest rate_limits record with a primary window in
          ~/.codex/sessions rollout files. Window lengths come from the record.
Gemini CLI and OpenCode expose no quota. They show a local session count, labelled
as activity. A reset time that is not in the data is never computed or guessed, and
a window whose reset time has passed is reported as stale, not as 0%.
"""
import datetime as dt
import glob
import json
import os
import re
import shutil
import sqlite3
import sys
import time
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
NOW = time.time()
STALE_S = int(os.environ.get("AGENT_STALE_MIN", "180")) * 60
WINDOW_S = {"5h": 5 * 3600, "7d": 7 * 86400}


def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def iso_to_ts(s):
    """ISO 8601 to epoch seconds. Python 3.9's fromisoformat only takes 3 or 6 fractional digits."""
    try:
        t = re.sub(r"\.(\d+)", lambda m: "." + (m.group(1) + "000000")[:6], str(s).replace("Z", "+00:00"))
        d = dt.datetime.fromisoformat(t)
        if d.tzinfo is None:
            return None           # a time without a zone could be off by hours; treat as unknown
        return d.timestamp()
    except (TypeError, ValueError):
        return None


def num(x):
    return float(x) if isinstance(x, (int, float)) and not isinstance(x, bool) else None


def window(key, used, resets_at, sampled_at):
    """One quota window.
    expired: the reset time passed, or a sample without reset time is older than its
             window. The value says nothing about the current window.
    stale:   the sample is older than AGENT_STALE_MIN. Within one window usage only
             grows, so the value is still a last-known upper bound on what is left."""
    used = max(0.0, min(100.0, used))
    expired = resets_at is not None and resets_at <= NOW
    if resets_at is None and sampled_at is not None and NOW - sampled_at > WINDOW_S.get(key, 0):
        expired = True
    # No sample time means the age is unknown, and unknown is not fresh.
    stale = expired or sampled_at is None or NOW - sampled_at > STALE_S
    return {"key": key, "used": round(used), "left": round(100 - used), "resets_at": resets_at,
            "sampled_at": sampled_at, "stale": stale, "expired": expired}


# ── Claude ────────────────────────────────────────────────────────────────────
def claude():
    detected = (HOME / ".claude.json").exists() or (HOME / ".claude").is_dir() or bool(shutil.which("claude"))
    out = {"provider": "claude", "kind": "quota", "detected": detected, "windows": [], "source": None}
    if not detected:
        return out
    cache = (load_json(HOME / ".claude.json") or {}).get("cachedUsageUtilization")
    cache = cache if isinstance(cache, dict) else {}
    util = cache.get("utilization")
    util = util if isinstance(util, dict) else {}
    cli_t = (num(cache.get("fetchedAtMs")) or 0) / 1000
    cli = []
    for src, key in (("five_hour", "5h"), ("seven_day", "7d")):
        r = util.get(src)
        r = r if isinstance(r, dict) else {}
        u = num(r.get("utilization"))
        if u is not None:
            cli.append(window(key, u, iso_to_ts(r.get("resets_at")), cli_t or None))

    app = []
    hist = load_json(HOME / "Library/Application Support/Claude/plan-usage-history.json")
    hist = hist if isinstance(hist, dict) else {}
    samples = hist.get("samples")
    samples = samples if isinstance(samples, list) else []
    app_t = 0
    if samples and isinstance(samples[-1], dict):
        s = samples[-1]
        app_t = (num(s.get("t")) or 0) / 1000
        u = s.get("u")
        u = u if isinstance(u, dict) else {}
        for src, key in (("fh", "5h"), ("sd", "7d")):
            v = num(u.get(src))
            if v is not None:
                app.append(window(key, v, None, app_t))
    if app and app_t > cli_t:
        out["windows"], out["source"] = app, "Claude desktop app"
    elif cli:
        out["windows"], out["source"] = cli, "Claude Code"
    return out


# ── Codex ─────────────────────────────────────────────────────────────────────
def codex_windows(lim, sampled_at):
    res = []
    for slot in ("primary", "secondary"):
        w = lim.get(slot)
        w = w if isinstance(w, dict) else {}
        u = num(w.get("used_percent"))
        if u is None:
            continue
        mins = num(w.get("window_minutes"))
        key = "5h" if mins and mins <= 360 else "7d" if mins and mins >= 10000 else ("%dm" % mins if mins else slot)
        res.append(window(key, u, num(w.get("resets_at")), sampled_at))
    return res


def codex():
    root = HOME / ".codex"
    detected = root.is_dir() or bool(shutil.which("codex"))
    out = {"provider": "codex", "kind": "quota", "detected": detected, "windows": [], "source": None}
    if not detected:
        return out
    files = [f for d in ("sessions", "archived_sessions")
             for f in glob.glob(str(root / d / "**" / "rollout-*.jsonl"), recursive=True)]
    # Newest by name date and newest by mtime: a resumed old session appends to an old name.
    def mtime(f):
        try:
            return os.path.getmtime(f)
        except OSError:           # deleted while we looked
            return 0
    cand = list(dict.fromkeys(sorted(files, key=os.path.basename, reverse=True)[:10]
                              + sorted(files, key=mtime, reverse=True)[:10]))
    best = None
    for f in cand:
        try:
            with open(f, "rb") as fh:
                fh.seek(max(0, os.path.getsize(f) - 200000))
                tail = fh.read().decode("utf8", "ignore")
        except OSError:
            continue
        for line in tail.split("\n"):
            if '"rate_limits"' not in line:
                continue
            try:
                row = json.loads(line)
            except ValueError:
                continue
            payload = row.get("payload") if isinstance(row, dict) else None
            lim = payload.get("rate_limits") if isinstance(payload, dict) else None
            prim = lim.get("primary") if isinstance(lim, dict) else None
            if not isinstance(prim, dict) or num(prim.get("used_percent")) is None:
                continue
            at = iso_to_ts(row.get("timestamp"))
            if at and (not best or at > best[0]):
                best = (at, lim)
    if best:
        out["windows"], out["source"] = codex_windows(best[1], best[0]), "Codex session log"
    return out


# ── Gemini CLI and OpenCode: local activity only ──────────────────────────────
def recent(files, cutoff, limit=25000):
    """Files modified since cutoff. None when the list is too long to count honestly:
    a truncated number would look exact."""
    n = 0
    for i, p in enumerate(files):
        if i >= limit:
            return None
        try:
            if os.stat(p).st_mtime >= cutoff:
                n += 1
        except OSError:
            continue
    return n


def gemini():
    root = Path(os.environ.get("GEMINI_DIR", str(HOME / ".gemini")))
    detected = root.is_dir() or bool(shutil.which("gemini"))
    out = {"provider": "gemini", "kind": "activity", "detected": detected, "sessions_7d": None}
    if detected:
        tmp = root / "tmp"
        files = (list(tmp.glob("*/chats/session-*.json")) + list(tmp.glob("*/chats/session-*.jsonl"))
                 + list(tmp.glob("session_*.json")))
        # An empty or unknown layout is "unknown", not "zero sessions".
        if files or any(tmp.glob("*/chats")):
            out["sessions_7d"] = recent(files, NOW - 7 * 86400)
    return out


def opencode():
    base = Path(os.environ.get("XDG_DATA_HOME", str(HOME / ".local/share"))) / "opencode"
    db = Path(os.environ.get("OPENCODE_DB") or base / "opencode.db")
    detected = base.is_dir() or db.is_file() or bool(shutil.which("opencode"))
    out = {"provider": "opencode", "kind": "activity", "detected": detected, "sessions_7d": None}
    cutoff = int(NOW - 7 * 86400)
    if db.is_file():
        try:
            con = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=0.25)
            try:
                con.execute("PRAGMA query_only=ON")
                tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
                for table in ("session", "session_v2"):
                    if table not in tables:
                        continue
                    cols = {r[1] for r in con.execute('PRAGMA table_info("%s")' % table)}
                    for col in ("time_created", "created_at", "time_updated", "updated_at"):
                        if col in cols:
                            # Unix milliseconds in current builds; accept seconds too.
                            q = ('SELECT COUNT(*) FROM "%s" WHERE CASE WHEN "%s" > 100000000000 '
                                 'THEN "%s" / 1000 ELSE "%s" END >= ?' % (table, col, col, col))
                            out["sessions_7d"] = int(con.execute(q, (cutoff,)).fetchone()[0])
                            return out
            finally:
                con.close()
        except (sqlite3.Error, OSError):
            pass
        return out        # schema unknown: do not claim zero sessions
    if (base / "storage/session").is_dir():
        out["sessions_7d"] = recent(list(base.glob("storage/session/**/ses_*.json")), cutoff)
    return out


PROVIDERS = {"claude": claude, "codex": codex, "gemini": gemini, "opencode": opencode}
NAMES = {"claude": "CLAUDE", "codex": "CODEX", "gemini": "GEMINI CLI", "opencode": "OPENCODE"}
LINKS = {"claude": "https://claude.ai/settings/usage", "codex": "https://chatgpt.com/codex"}


def get(provider):
    # The inputs are files other programs write and may change. Whatever is in them, one
    # provider failing must not take the others, or the bar, down.
    try:
        return PROVIDERS[provider]()
    except Exception:  # noqa: BLE001
        kind = "activity" if provider in ("gemini", "opencode") else "quota"
        return {"provider": provider, "kind": kind, "detected": False, "windows": [], "sessions_7d": None}


# ── formatting ────────────────────────────────────────────────────────────────
def short_window(d):
    """The window the bar shows: the shortest one."""
    ws = [w for w in d.get("windows", [])]
    return ws[0] if ws else None


def severity(left):
    return "err" if left <= 10 else "warn" if left <= 25 else "text"


def bar(provider, value="left"):
    d = get(provider)
    if not d["detected"]:
        return "—", "text3", 0
    if d["kind"] == "activity":
        n = d.get("sessions_7d")
        return ("%d/7d" % n if n is not None else "—"), "text2", 1
    w = short_window(d)
    if not w or w["expired"]:
        return "—", "text3", 1
    v = w["left"] if value == "left" else w["used"]
    if w["stale"]:
        return "~%d%%" % v, "text3", 1      # last known, not current
    return "%d%%" % v, severity(w["left"]), 1


def countdown(ts):
    secs = ts - NOW
    if secs <= 0:
        return None
    m = int((secs + 59) // 60)
    d, rem = divmod(m, 1440)
    h, mm = divmod(rem, 60)
    if d:
        return "%dd %dh" % (d, h) if h else "%dd" % d
    if h:
        return "%dh %dm" % (h, mm) if mm else "%dh" % h
    return "%dm" % mm


def age(ts):
    s = NOW - ts
    return "%dm" % max(1, s // 60) if s < 3600 else "%dh" % (s // 3600) if s < 86400 else "%dd" % (s // 86400)


def meter(left):
    lit = int(round(left / 12.5))
    return "▰" * lit + "▱" * (8 - lit)


def rows(providers, refresh_cmd):
    pal = {k: os.environ.get("AGENT_" + k.upper(), "0xffffffff") for k in ("text", "text2", "text3", "accent", "warn", "err")}
    out = []

    def row(kind, key, text, colour, click=""):
        out.append("\t".join((kind, key, text, colour, click)))

    shown = 0
    for p in providers:
        d = get(p)
        if not d["detected"]:
            continue
        shown += 1
        row("H", "_", NAMES[p] + ("  ↗" if p in LINKS else ""), pal["text2"],
            "open " + LINKS[p] if p in LINKS else "")
        if d["kind"] == "activity":
            n = d.get("sessions_7d")
            row("N", "_", "local sessions, 7 days: %s" % (n if n is not None else "unavailable"),
                pal["text"] if n is not None else pal["text3"])
            row("N", "_", "activity count, not a quota", pal["text3"])
            continue
        if not d["windows"]:
            row("N", "_", "no quota windows reported", pal["text3"])
            continue
        for w in d["windows"]:
            if w["expired"]:
                row("M", "·" * 8, "%s   window reset · no newer sample" % w["key"], pal["text3"], pal["text3"])
                continue
            rs = countdown(w["resets_at"]) if w["resets_at"] is not None else None
            tail = ("resets in " + rs) if rs else "reset time unknown"
            if w["stale"]:
                tail = "%s old · %s" % (age(w["sampled_at"]), tail.replace("resets in", "resets"))
                row("M", meter(w["left"]), "%s   ≤%d%% left · %s" % (w["key"], w["left"], tail),
                    pal["text3"], pal["text3"])
                continue
            colour = pal[{"text": "accent"}.get(severity(w["left"]), severity(w["left"]))]
            row("M", meter(w["left"]), "%s   %d%% left · %s" % (w["key"], w["left"], tail), pal["text"], colour)
        if d.get("source"):
            row("N", "_", "source: " + d["source"], pal["text3"])
    if not shown:
        row("N", "_", "no providers detected", pal["text3"])
    row("F", "_", "↻  Refresh", pal["text2"], refresh_cmd)
    return out


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "data":
        print(json.dumps({p: get(p) for p in PROVIDERS}))
    elif cmd == "bar":
        label, role, det = bar(sys.argv[2], os.environ.get("AGENT_BAR_VALUE", "left"))
        print("%s\t%s\t%d" % (label, role, det))
    elif cmd == "rows":
        print("\n".join(rows(sys.argv[2:], os.environ.get("AGENT_REFRESH", ""))))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
