#!/usr/bin/env python3
"""Run every sw/build/*.hex on the simulator and print a PASS/FAIL table.
usage: run_tests.py [--sim obj/<cfg>/Vtb_top] [--build sw/build] [--filter rv32ui] [--trace]"""
import argparse, glob, os, re, subprocess, sys

ap = argparse.ArgumentParser()
ap.add_argument("--sim", default="obj/riscv_pipe_m1_bp0/Vtb_top")
ap.add_argument("--build", default="sw/build")
ap.add_argument("--filter", default="")
ap.add_argument("--trace", action="store_true", help="also write <name>.trace (spike-like commit log)")
ap.add_argument("--timeout", type=int, default=200000)
args = ap.parse_args()

hexes = sorted(h for h in glob.glob(f"{args.build}/*.hex") if args.filter in os.path.basename(h))
if not hexes:
    sys.exit("no .hex files found - run `make -C sw` first")

n_pass = 0; rows = []
for h in hexes:
    name = os.path.basename(h)[:-4]
    tohost = open(h[:-4] + ".tohost").read().strip()
    cmd = [args.sim, f"+HEX={h}", f"+TOHOST={tohost}", f"+TIMEOUT={args.timeout}"]
    if args.trace: cmd.append(f"+TRACE={h[:-4]}.trace")
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    m = re.search(r"RESULT (\w+)(?: testcase=(\d+))? cycles=(\d+) instret=(\d+)", out)
    if not m:
        rows.append((name, "ERROR", "-", "-")); continue
    status, tc, cyc, ins = m.group(1), m.group(2), int(m.group(3)), int(m.group(4))
    if status == "PASS": n_pass += 1
    detail = f"{status}" + (f" (case {tc})" if tc else "")
    rows.append((name, detail, cyc, f"{cyc / max(ins, 1):.2f}"))

w = max(len(r[0]) for r in rows)
for r in rows:
    print(f"{r[0]:<{w}}  {r[1]:<16} cycles={r[2]:<8} CPI={r[3]}")
print(f"\n{n_pass}/{len(rows)} passed")
sys.exit(0 if n_pass == len(rows) else 1)
