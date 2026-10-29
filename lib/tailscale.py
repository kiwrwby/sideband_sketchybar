#!/usr/bin/env python3
"""Reduces `tailscale status --json` to rows for the bar.

  tailscale.py < status.json

Line 1: state<TAB>tailnet name  (state is BackendState, empty on bad input)
Then one line per device, this device first, then online by name, then offline:
  name<TAB>ip<TAB>online 0/1<TAB>self 0/1<TAB>vnc host (online macOS peers) or empty
A common name prefix (for example "alice-") is dropped from every name.
"""
import json
import os.path
import sys


def full(p):
    return (p.get("DNSName") or "").split(".")[0] or p.get("HostName", "?")


def main():
    try:
        d = json.load(sys.stdin)
    except ValueError:
        d = {}
    state = d.get("BackendState", "")
    net = (d.get("CurrentTailnet") or {}).get("Name") or ""
    print("%s\t%s" % (state, net))
    if state != "Running":
        return
    me = d.get("Self") or {}
    peers = list((d.get("Peer") or {}).values())
    names = [full(p) for p in [me] + peers]
    pre = os.path.commonprefix(names)
    pre = pre[:pre.rfind("-") + 1] if len(names) > 1 and "-" in pre else ""

    def name(p):
        return full(p)[len(pre):] or full(p)

    def ip(p):
        return (p.get("TailscaleIPs") or [""])[0]

    print("%s\t%s\t1\t1\t" % (name(me), ip(me)))
    for p in sorted(peers, key=lambda p: (not p.get("Online"), name(p)))[:7]:
        online = 1 if p.get("Online") else 0
        vnc = (p.get("DNSName") or "").rstrip(".") if online and p.get("OS") == "macOS" else ""
        print("%s\t%s\t%d\t0\t%s" % (name(p), ip(p), online, vnc))


if __name__ == "__main__":
    main()
