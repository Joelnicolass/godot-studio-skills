"""PASS/FAIL for one run_lab.sh scenario: check_lab.py OUTDIR rooms|rematch.

rooms   A (slot 1, room r_1) and late B (slot 2, room r_2) get every main actor the
        server spawned, only their own room's actors, and S / static ticks that grow.
        After slot 1 is unseated (9 s), A's last report has no r_1 actors; B keeps r_2.
rematch After the server reloads the world, A and B get the new world's actors and
        their own room again, and S / static ticks grow.
Both    Client errors: only ERR_INVALID_DATA for the deferred-sync actor (D, engine
        limit) and MpReplicate for L (no synchronizer on purpose). Server errors: only
        MpSpawner's report of D. No peers_info errors when peers leave."""
import re
import sys
from pathlib import Path

out = Path(sys.argv[1])
mode = sys.argv[2] if len(sys.argv) > 2 else "rooms"
logs = {k: (out / f"{k}.log").read_text(errors="replace") for k in ("server", "a", "b")}
fails = []
ROOMS = {"a": ("ra_", "rb_"), "b": ("rb_", "ra_")}


def report(log, tag):
    found = re.findall(r"LAB\|slot=\d\|%s\|(.*)" % tag, log)
    if not found:
        return None
    return {p.rsplit(":", 1)[0]: int(p.rsplit(":", 1)[1]) for p in found[-1].split()}


def spawned(log):
    names = []
    for line in re.findall(r"LAB\|server\|spawn (.*)", log):
        names += line.split()
    return names


def check_growing(key, before, after):
    if before is None:
        fails.append(f"{key}: no earlier report to compare")
        return
    for n, tick in after.items():
        # Only actors already there in the earlier report (a fresh one may still be at 0).
        if (n.endswith("_S") or n == "static") and n in before:
            if tick <= before[n]:
                fails.append(f"{key}: {n} not syncing ({before[n]} -> {tick})")


def check_world(key, names, rep, own, other, skip=()):
    for n in names:
        if n.startswith(("ra_", "rb_")) or n.startswith(skip):
            continue
        if n not in rep:
            fails.append(f"{key}: missing {n}")
    for n in names:
        if n.startswith(own) and n not in rep:
            fails.append(f"{key}: missing own-room {n}")
        if n.startswith(other) and n in rep:
            fails.append(f"{key}: sees other room {n}")


if mode == "rooms":
    names = spawned(logs["server"])
    for key in ("a", "b"):
        own, other = ROOMS[key]
        t3, t5, t9 = (report(logs[key], t) for t in ("t3", "t5", "t9"))
        if t5 is None or t9 is None:
            fails.append(f"{key}: missing report (t5={t5 is not None}, t9={t9 is not None})")
            continue
        # B's batches (j2, r2) land around A's t5 report.
        check_world(key, names, t5, own, other, skip=("j2", "r2") if key == "a" else ())
        check_growing(key, t3, t5)
        if key == "a":
            kept = [n for n in t9 if n.startswith("ra_")]
            if kept:
                fails.append(f"a: still has room actors after unseat: {kept}")
            if "b0_S" not in t9:
                fails.append("a: lost main actors after unseat")
        else:
            if "rb_S" not in t9:
                fails.append("b: lost own room after A was unseated")
    if "unseat slot=1" not in logs["server"]:
        fails.append("server: unseat did not run")
else:
    server = logs["server"]
    if "LAB|server|rematch" not in server:
        fails.append("server: rematch did not run")
    names = spawned(server.split("LAB|server|rematch", 1)[-1])
    for key in ("a", "b"):
        own, other = ROOMS[key]
        w3, w5 = report(logs[key], "w2t3"), report(logs[key], "w2t5")
        if w5 is None:
            fails.append(f"{key}: no report in the reloaded world")
            continue
        check_world(key, names, w5, own, other)
        check_growing(key, w3, w5)

for key in ("a", "b"):
    for e in (l for l in logs[key].splitlines() if l.startswith(("ERROR", "SCRIPT ERROR"))):
        if "MpReplicate" in e or "ERR_INVALID_DATA" in e:
            continue
        fails.append(f"{key}: {e}")
for e in (l for l in logs["server"].splitlines() if l.startswith(("ERROR", "SCRIPT ERROR"))):
    if "added after its node was set up" in e or "MpReplicate" in e:
        continue
    fails.append(f"server: {e}")

if fails:
    print(f"FAIL {mode}")
    for f in dict.fromkeys(fails):
        print("  " + f)
    sys.exit(1)
print(f"PASS {mode}")
