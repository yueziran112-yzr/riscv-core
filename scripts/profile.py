#!/usr/bin/env python3
"""Instruction-mix profile of a commit trace (from +TRACE=...), and a CPI estimate.
usage: profile.py trace.log [--mul-lat 33] [--div-lat 33] [--br-pen 2]
CPI_est = 1 + f_taken_cf * br_pen + f_load_use * 1 + f_mul * mul_lat + f_div * div_lat
(predict-not-taken pipeline, branches resolved in EX)"""
import argparse, re
ap = argparse.ArgumentParser()
ap.add_argument("trace"); ap.add_argument("--mul-lat", type=int, default=33)
ap.add_argument("--div-lat", type=int, default=33); ap.add_argument("--br-pen", type=int, default=2)
a = ap.parse_args()
pat = re.compile(r"0x([0-9a-fA-F]+)\s+\(0x([0-9a-fA-F]+)\)")
tr = [(int(m.group(1), 16), int(m.group(2), 16)) for m in map(pat.search, open(a.trace)) if m]
n = len(tr)
c = dict(branch=0, taken=0, jal=0, jalr=0, load=0, load_use=0, store=0, mul=0, div=0)
def rs(i): return (i >> 15) & 31, (i >> 20) & 31
for k, (pc, ins) in enumerate(tr):
    op = ins & 0x7F
    nxt = tr[k + 1][0] if k + 1 < n else pc + 4
    if op == 0x63:
        c["branch"] += 1; c["taken"] += (nxt != pc + 4)
    elif op == 0x6F: c["jal"] += 1
    elif op == 0x67: c["jalr"] += 1
    elif op == 0x03:
        c["load"] += 1
        if k + 1 < n:
            rd = (ins >> 7) & 31; ni = tr[k + 1][1]; nop = ni & 0x7F
            r1, r2 = rs(ni)
            uses1 = nop not in (0x37, 0x17, 0x6F)                 # LUI, AUIPC, JAL read no register
            uses2 = nop in (0x33, 0x23, 0x63)                     # OP, STORE, BRANCH read rs2
            if rd and ((uses1 and r1 == rd) or (uses2 and r2 == rd)): c["load_use"] += 1
    elif op == 0x23: c["store"] += 1
    elif op == 0x33 and (ins >> 25) == 1:
        c["div" if (ins >> 14) & 1 else "mul"] += 1
taken_cf = c["taken"] + c["jal"] + c["jalr"]
print(f"instructions: {n}")
for key in c: print(f"  {key:<9} {c[key]:>8}  ({100 * c[key] / max(n, 1):5.1f} %)")
est = 1 + (taken_cf * a.br_pen + c["load_use"] + c["mul"] * a.mul_lat + c["div"] * a.div_lat) / max(n, 1)
print(f"taken branches+jumps: {taken_cf}")
print(f"CPI estimate: {est:.3f}   (br_pen={a.br_pen}, mul_lat={a.mul_lat}, div_lat={a.div_lat})")
