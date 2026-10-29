#!/usr/bin/env python3
"""Builds the calendar popup: row table and per-row coloured spans.

  cal_popup.py <month offset> <out dir>

Environment: SBD_HELPERS, SBD_CACHE, HOLIDAY_CAL, STEP_CMD (click template with
the marker SENDER=), and colours TEXT TEXT3 ERR BLUE (0xAARRGGBB).

Writes <out dir>/rows (key, text, colour, click per line, fixed length) and
<out dir>/row3..row9 (span files for textspans: colour<TAB>text per line).
Row 3 is the weekday header, rows 4-9 are the weeks.
"""
import calendar as cal
import datetime as dt
import os
import subprocess
import sys

MAX_EVENTS = 16     # popup height cap: fits a MacBook screen
ROWS = 28           # fixed row count: 4 + 6 weeks + events + link
env = os.environ.get
TEXT, TEXT3, ERR, BLUE = env("TEXT"), env("TEXT3"), env("ERR"), env("BLUE")


def helper(*args):
    try:
        p = subprocess.run([os.path.join(env("SBD_HELPERS"), "events")] + list(args),
                           capture_output=True, text=True, timeout=10)
        return p.stdout if p.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""


def shift_month(d, n):
    m = d.month - 1 + n
    return dt.date(d.year + m // 12, m % 12 + 1, 1)


def holiday_ids():
    name = env("HOLIDAY_CAL", "")
    if not name:
        return ""
    cache = os.path.join(env("SBD_CACHE"), "holiday.cal")
    try:
        with open(cache) as f:
            got = f.read().strip()
            if got:
                return got
    except OSError:
        pass
    got = helper("calid", name).strip()
    if got:
        with open(cache, "w") as f:
            f.write(got)
    return got


def merge_holidays(rows, year):
    """Consecutive days with the same name become one range row."""
    def parse(k):
        a, _, b = k.partition("-")
        return a, b or a

    def day(s):
        return dt.date(year, int(s[:2]), int(s[3:]))

    out = []
    for key, name in rows:
        a, b = parse(key)
        if out and out[-1][2] == name and day(out[-1][1]) + dt.timedelta(days=1) == day(a):
            out[-1][1] = b
        else:
            out.append([a, b, name])
    return [("%s-%s" % (a, b) if a != b else a, n) for a, b, n in out]


def month_days_in(rows, year, month):
    days = set()
    for key, _ in rows:
        a, _, b = key.partition("-")
        b = b or a
        d, e = dt.date(year, int(a[:2]), int(a[3:])), dt.date(year, int(b[:2]), int(b[3:]))
        while d <= e:
            if d.month == month:
                days.add(d.day)
            d += dt.timedelta(days=1)
    return days


def split(text):
    return [tuple(l.split("\t", 1)) for l in text.splitlines() if "\t" in l]


def main():
    off, out = int(sys.argv[1]), sys.argv[2]
    os.makedirs(out, exist_ok=True)
    today = dt.date.today()
    base = shift_month(today.replace(day=1), off)
    first = (base.weekday() + 1) % 7          # Sunday = 0
    days = cal.monthrange(base.year, base.month)[1]
    prev_m = shift_month(base, -1).strftime("%m")
    next_m = shift_month(base, 1).strftime("%m")
    today_n = today.day if off == 0 else 0

    hid = holiday_ids()
    raw_h = split(helper(base.isoformat(), hid)) if hid else []
    raw_all = split(helper(base.isoformat()))
    holidays = merge_holidays(raw_h, base.year)
    events = [e for e in raw_all if e not in set(raw_h)]
    hdays = month_days_in(holidays, base.year, base.month)

    step = env("STEP_CMD", "")
    def step_cmd(n):
        return step.replace("SENDER=", "CAL_STEP=%d SENDER=" % n, 1)

    rows = []
    rows.append(("=", " " * 32 + "●", TEXT, step_cmd(0)))     # year-month is overlaid as the icon
    rows.append(("=", " ‹ " + prev_m, TEXT3, step_cmd(-1)))
    rows.append(("=", " " * 29 + next_m + " ›", TEXT3, step_cmd(1)))
    rows.append(("=", " SU   MO   TU   WE   TH   FR   SA", TEXT3, ""))
    with open(os.path.join(out, "row3"), "w") as f:
        f.write("%s\t \n%s\tSU\n%s\t   MO   TU   WE   TH   FR   \n%s\tSA\n" % (TEXT3, ERR, TEXT3, BLUE))

    row, spans, line = 4, ["%s\t%s\n" % (TEXT, " " * (first * 5))], " " * (first * 5)
    for d in range(1, days + 1):
        w = (first + d - 1) % 7
        dc = BLUE if w == 6 else TEXT
        if w == 0 or d in hdays:
            dc = ERR                                   # Sundays and holidays; Saturday holidays too
        if d == today_n:
            line += "[%2d] " % d
            spans.append("%s\t[\n%s\t%2d\n%s\t] \n" % (TEXT, dc, d, TEXT))
        else:
            line += " %2d  " % d
            spans.append("%s\t \n%s\t%2d\n%s\t  \n" % (TEXT, dc, d, TEXT))
        if (first + d) % 7 == 0 or d == days:
            rows.append(("=", line.rstrip(), TEXT, ""))
            with open(os.path.join(out, "row%d" % row), "w") as f:
                f.write("".join(spans))
            row, spans, line = row + 1, [], ""

    ev = sorted([(k, n, TEXT) for k, n in events] + [(k, n, ERR) for k, n in holidays], key=lambda x: x[0])
    for k, n, c in ev[:MAX_EVENTS]:
        rows.append((k, n, c, "open -a Calendar"))
    if len(ev) > MAX_EVENTS:
        rows.append(("_", "+%d more" % (len(ev) - MAX_EVENTS), TEXT3, "open -a Calendar"))
    rows.append(("_", "Calendar ↗", env("TEXT2", TEXT3), "open -a Calendar"))
    while len(rows) < ROWS:
        rows.append(("~", ".", "", ""))
    with open(os.path.join(out, "rows"), "w") as f:
        for r in rows[:ROWS]:
            f.write("\t".join(r) + "\n")
    with open(os.path.join(out, "meta"), "w") as f:
        f.write("%s\t%s\n" % (base.strftime("%Y.%m"), off))


if __name__ == "__main__":
    main()
