#!/usr/bin/env python3
"""Pilo agents -> bar state. Reads the JSON of `pilo api GET /api/agents` on stdin.

Line 1: most urgent state<TAB>number of agents waiting on a decision
Then one line per agent, parents before their workers:
  name<TAB>one-line text<TAB>state
Exit 1 on unusable input, so the caller can tell "no answer" from "no agents".

States follow Pilo's agent state ladder. Urgency order:
blocked > failed > gaveUp > stalled > running > limited > unbound > idle
"""
import datetime as dt
import json
import sys
import unicodedata

RANK = ["blocked", "failed", "gaveUp", "stalled", "running", "limited", "unbound", "idle"]
NOW = dt.datetime.now(dt.timezone.utc)


def ts(s):
    try:
        return dt.datetime.fromisoformat(str(s).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None


def state(a):
    lim = ts(a.get("limitedUntil") or "")
    if lim and lim > NOW:
        return "limited"
    if (a.get("gaveUp") or 0) > 0:
        return "gaveUp"
    st, ss, sig = a.get("status"), a.get("sessionStatus"), ts(a.get("lastSignal") or "")
    if st == "running" and sig and ss != "working" and (NOW - sig).total_seconds() > 600:
        return "stalled"
    if st in ("blocked", "failed", "unbound"):
        return st
    return "running" if st == "running" or ss == "working" else "idle"


def one(x, n=48):
    """One line, cut at n display columns (wide characters count 2)."""
    out, w = "", 0
    for ch in " ".join(str(x or "").split()):
        w += 2 if unicodedata.east_asian_width(ch) in "WF" else 1
        if w > n:
            return out + "…"
        out += ch
    return out


def line(a, s):
    if s == "blocked":
        return one(a.get("blockedQuestion")) or "waiting on a decision"
    if s == "limited":
        return "limited until " + ts(a["limitedUntil"]).astimezone().strftime("%m.%d %H:%M")
    word = {"gaveUp": "wake failed", "stalled": "stalled", "failed": "failed", "unbound": "no session",
            "running": "running", "idle": "idle"}[s]
    p = one(a.get("progress") or a.get("activity"))
    if s == "running" and p:
        return p
    return one(word + " · " + p) if p and s != "idle" else word


def main():
    try:
        agents = [a for a in json.load(sys.stdin) if a.get("role") != "system"]
    except (ValueError, TypeError):
        sys.exit(1)
    if not isinstance(agents, list) or not agents:
        sys.exit(1)
    st = {a["id"]: state(a) for a in agents}
    print(min(st.values(), key=RANK.index), sum(1 for v in st.values() if v == "blocked"), sep="\t")
    ids = {a["id"] for a in agents}

    def walk(parent, seen):
        kids = [a for a in agents
                if (a.get("parentAgentId") if a.get("parentAgentId") in ids else None) == parent and a["id"] not in seen]
        for a in sorted(kids, key=lambda a: (a.get("role") != "pilo", a["name"])):
            seen.add(a["id"])
            print(("· " if a.get("role") == "worker" else "") + a["name"], line(a, st[a["id"]]), st[a["id"]], sep="\t")
            walk(a["id"], seen)

    walk(None, set())


if __name__ == "__main__":
    main()
