#!/usr/bin/env python3
"""Run the C benchmarks on one simulator build and print cycles / instret / CPI.
usage: run_bench.py --sim obj/<cfg>/Vtb_top [--build sw/bench/build] [--trace] [--csv out.csv]
With --trace, also writes <bench>.trace for scripts/profile.py."""
import argparse, glob, os, re, subprocess, sys
ap = argparse.ArgumentParser()
ap.add_argument("--sim", required=True)
ap.add_argument("--build", default="sw/bench/build")
ap.add_argument("--trace", action="store_true")
ap.add_argument("--csv")
a = ap.parse_args()
rows = []
for h in sorted(glob.glob(f"{a.build}/*.hex")):
    name = os.path.basename(h)[:-4]
    tohost = open(h[:-4] + ".tohost").read().strip()
    cmd = [a.sim, f"+HEX={h}", f"+TOHOST={tohost}", "+TIMEOUT=20000000"]
    if a.trace: cmd.append(f"+TRACE={h[:-4]}.trace")
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    m = re.search(r"RESULT (\w+)(?: testcase=\d+)? cycles=(\d+) instret=(\d+)", out)
    if not m: rows.append((name, "ERROR", 0, 0)); continue
    rows.append((name, m.group(1), int(m.group(2)), int(m.group(3))))
    st = re.search(r"BPSTAT (.*)", out)
    if st: print(f"{name:<8} {st.group(1)}")
print(f"{'bench':<8} {'result':<7} {'cycles':>9} {'instret':>9} {'CPI':>6}")
for n, r, c, i in rows:
    print(f"{n:<8} {r:<7} {c:>9} {i:>9} {c / max(i, 1):>6.3f}")
if a.csv:
    with open(a.csv, "w") as f:
        f.write("bench,result,cycles,instret,cpi\n")
        for n, r, c, i in rows: f.write(f"{n},{r},{c},{i},{c / max(i, 1):.4f}\n")
sys.exit(0 if all(r[1] == "PASS" for r in rows) else 1)
