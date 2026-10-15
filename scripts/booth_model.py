#!/usr/bin/env python3
"""Bit-accurate Python model of the radix-4 Booth iterative multiplier described in the manual.
Prints the register state after every iteration so you can compare it with your waveform.

usage: booth_model.py A B [--mode mul|mulh|mulhsu|mulhu]      (A, B: decimal or 0x.. hex)
       booth_model.py --selftest                                 (random check against Python *)

Registers (same names as the manual):
  x    : 33-bit signed multiplicand  (a, sign- or zero-extended)
  q    : 34-bit multiplier register  (b, extended to 34 bits), shifted right by 2 per step
  q_m1 : the bit to the right of q[0] (starts at 0)
  h    : 36-bit signed partial-product register
Each step:  d = booth(q[1], q[0], q_m1);  h = h + d*x;  {h, q} = {h, q} >>> 2 (arithmetic);  q_m1 = old q[1]
After 17 steps the 64-bit product is {h[29:0], q[33:0]}."""
import argparse, random, sys

def sx(v, bits):                       # interpret v as a signed number of `bits` bits
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v

BOOTH = {0b000: 0, 0b001: 1, 0b010: 1, 0b011: 2, 0b100: -2, 0b101: -1, 0b110: -1, 0b111: 0}

def booth_mul(a, b, mode="mul", trace=False):
    a_sgn = mode in ("mulh", "mulhsu"); b_sgn = mode == "mulh"
    x = sx(a, 32) if a_sgn else a & 0xFFFFFFFF            # 33-bit signed value
    yv = sx(b, 32) if b_sgn else b & 0xFFFFFFFF
    q = yv & ((1 << 34) - 1)                               # 34-bit register contents
    q_m1, h = 0, 0
    if trace: print(f"init : x={x & ((1<<33)-1):09x}  q={q:09x}  q_m1=0  h=0")
    for step in range(17):
        d = BOOTH[((q & 3) << 1) | q_m1]
        h = sx(h + d * x, 36)
        both = ((h & ((1 << 36) - 1)) << 34) | q             # 70-bit {h, q}
        both = sx(both, 70) >> 2                             # arithmetic shift right by 2
        new_q_m1 = (q >> 1) & 1
        q = both & ((1 << 34) - 1); h = sx(both >> 34, 36); q_m1 = new_q_m1
        if trace: print(f"step {step:2d}: d={d:+d}  h={h & ((1<<36)-1):09x}  q={q:09x}  q_m1={q_m1}")
    prod = (((h & ((1 << 30) - 1)) << 34) | q) & ((1 << 64) - 1)
    return prod & 0xFFFFFFFF if mode == "mul" else prod >> 32

def ref(a, b, mode):
    sa = sx(a, 32) if mode in ("mulh", "mulhsu") else a
    sb = sx(b, 32) if mode == "mulh" else b
    p = (sa * sb) & ((1 << 64) - 1)
    return p & 0xFFFFFFFF if mode == "mul" else p >> 32

ap = argparse.ArgumentParser()
ap.add_argument("a", nargs="?"); ap.add_argument("b", nargs="?")
ap.add_argument("--mode", default="mul", choices=["mul", "mulh", "mulhsu", "mulhu"])
ap.add_argument("--selftest", action="store_true")
args = ap.parse_args()
if args.selftest:
    edge = [0, 1, 2, 0x7FFFFFFF, 0x80000000, 0xFFFFFFFF, 0xFFFFFFFE, 0xFFFF]
    cases = [(x, y) for x in edge for y in edge] + [(random.getrandbits(32), random.getrandbits(32)) for _ in range(5000)]
    bad = sum(booth_mul(x, y, m) != ref(x, y, m) for x, y in cases for m in ("mul", "mulh", "mulhsu", "mulhu"))
    print("selftest:", "PASS" if bad == 0 else f"FAIL ({bad})"); sys.exit(bad != 0)
if args.a is None: ap.error("give A and B, or --selftest")
A, B = int(args.a, 0) & 0xFFFFFFFF, int(args.b, 0) & 0xFFFFFFFF
r = booth_mul(A, B, args.mode, trace=True)
print(f"result ({args.mode}) = 0x{r:08x}   reference = 0x{ref(A, B, args.mode):08x}")
