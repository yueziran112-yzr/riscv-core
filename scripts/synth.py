#!/usr/bin/env python3
"""Yosys synthesis wrapper. Generic gates by default; SKY130 standard cells with --lib.
usage: synth.py --top riscv_core --files a.sv b.sv ... [--param MUL_IMPL=3] [--lib sky130.lib] [--tag name]
Reports: cell count, flip-flops, area (um^2 with --lib), ABC combinational delay (ps, with --lib),
and the longest topological path (logic levels) with its start/end point."""
import argparse, os, re, subprocess, sys
ap = argparse.ArgumentParser()
ap.add_argument("--top", required=True); ap.add_argument("--files", nargs="+", required=True)
ap.add_argument("--param", action="append", default=[]); ap.add_argument("--lib")
ap.add_argument("--tag", default="design"); ap.add_argument("--outdir", default="synth/out")
a = ap.parse_args()
os.makedirs(a.outdir, exist_ok=True)
chp = " ".join(f"-chparam {p.split('=')[0]} {p.split('=')[1]}" for p in a.param)
ys = [f"read_verilog -defer -sv {' '.join(a.files)}",
      f"hierarchy -top {a.top} {chp}",
      "synth -flatten -top " + a.top,
      f"tee -q -o {a.outdir}/{a.tag}.ltp ltp -noff"]          # logic depth on generic gates
if a.lib:
    ys += [f"dfflibmap -liberty {a.lib}",
           f"abc -liberty {a.lib} -script +strash;dch,-f;map,-M,1;topo;stime,-p",
           "opt_clean", f"stat -liberty {a.lib}"]
else:
    ys += ["abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX", "opt_clean", "stat"]
ys += [f"write_verilog -noattr {a.outdir}/{a.tag}_netlist.v"]
script = f"{a.outdir}/{a.tag}.ys"; log = f"{a.outdir}/{a.tag}.log"
open(script, "w").write("\n".join(ys) + "\n")
r = subprocess.run(["yosys", "-q", "-l", log, "-s", script], capture_output=True, text=True)
if r.returncode:
    print(r.stdout[-2000:], r.stderr[-2000:]); sys.exit("yosys failed, see " + log)
FULL = open(log).read()
L = FULL[FULL.rfind("Printing statistics"):] if "Printing statistics" in FULL else FULL   # last stat block only
cells = re.findall(r"^\s+(\d+)\s+[\d.E+-]*\s*cells$", L, re.M) or re.findall(r"Number of cells:\s+(\d+)", L)
ffs = sum(int(x) for x in re.findall(r"^\s+(\d+)\s+[\d.E+-]*\s*\S*(?:dfxtp|dfrtp|dfstp|dfbbp|edfxtp|_DFF\w*|_SDFF\w*|_DLATCH\w*)\S*\s*$", L, re.M))
area = re.findall(r"Chip area for (?:top )?module.*?:\s*([\d.]+)", L)
delay = re.findall(r"Delay\s*=\s*([\d.]+)\s*ps", FULL)
ltp = open(f"{a.outdir}/{a.tag}.ltp").read()
m = re.search(r"length=(\d+)", ltp)
pts = re.findall(r"^\s+(?:\d+|ff):\s+(\S+)", ltp, re.M)
res = {"tag": a.tag, "cells": cells[-1] if cells else "?", "ffs": ffs,
       "area_um2": area[-1] if area else "-", "abc_delay_ps": delay[-1] if delay else "-",
       "logic_levels": m.group(1) if m else "?", "path_start": pts[0] if pts else "?", "path_end": pts[-1] if pts else "?"}
for k, v in res.items(): print(f"{k:<13} {v}")
with open(f"{a.outdir}/summary.csv", "a") as f:
    f.write(",".join(str(v) for v in res.values()) + "\n")
