#!/usr/bin/env python3
"""Differential random test: for each seed generate a program, run it on the single-cycle core
(reference) and on the pipelined core, and compare the commit traces."""
import argparse, os, subprocess, sys, re
ap = argparse.ArgumentParser()
ap.add_argument("--n", type=int, default=30); ap.add_argument("--len", type=int, default=300)
ap.add_argument("--first", type=int, default=1)
ap.add_argument("--ref-sim", default="obj_sc/Vtb_top"); ap.add_argument("--dut-sim", default="obj_pipe/Vtb_top")
a = ap.parse_args()
rt = os.environ.get("RISCV_TESTS", os.path.expanduser("~/riscv-tests")); cross = os.environ.get("CROSS", "riscv-none-elf-")
out = "sw/build_rand"; os.makedirs(out, exist_ok=True)
cflags = ["-march=rv32im", "-mabi=ilp32", "-static", "-mcmodel=medany", "-nostdlib", "-nostartfiles",
          "-I", "sw/env", "-I", f"{rt}/isa/macros/scalar", "-T", "sw/env/link.ld", "-Wl,--no-warn-rwx-segments"]
def sh(cmd, **kw): return subprocess.run(cmd, capture_output=True, text=True, **kw)
bad = 0
for seed in range(a.first, a.first + a.n):
    base = f"{out}/r{seed}"
    open(base + ".S", "w").write(sh(["python3", "scripts/gen_random_test.py", str(seed), str(a.len)]).stdout)
    r = sh([cross + "gcc", *cflags, base + ".S", "-o", base + ".elf"])
    if r.returncode: print(f"seed {seed}: ASSEMBLE ERROR\n{r.stderr[:500]}"); bad += 1; continue
    sh([cross + "objcopy", "-O", "binary", base + ".elf", base + ".bin"]); sh(["python3", "scripts/bin2hex.py", base + ".bin", base + ".hex"])
    tohost = [l.split()[0] for l in sh([cross + "nm", base + ".elf"]).stdout.splitlines() if l.endswith(" tohost")][0]
    res = {}
    for tag, sim in (("ref", a.ref_sim), ("dut", a.dut_sim)):
        o = sh([sim, f"+HEX={base}.hex", f"+TOHOST={tohost}", f"+TRACE={base}.{tag}.trace", "+TIMEOUT=300000"]).stdout
        res[tag] = re.search(r"RESULT (\w+).*cycles=(\d+) instret=(\d+)", o)
    ok = all(res[t] and res[t].group(1) == "PASS" for t in res)
    cmp = sh(["python3", "scripts/compare_trace.py", base + ".ref.trace", base + ".dut.trace"])
    if ok and cmp.returncode == 0:
        c1, c2 = int(res["ref"].group(2)), int(res["dut"].group(2))
        print(f"seed {seed:3d}: OK   {cmp.stdout.strip().split(':')[1].split('commits')[0].strip():>5} commits   CPI(pipe)={c2 / max(int(res['dut'].group(3)), 1):.2f}")
    else:
        bad += 1; print(f"seed {seed:3d}: FAIL  {cmp.stdout.strip()}  sim: {[(t, res[t].group(1) if res[t] else None) for t in res]}")
print(f"\n{a.n - bad}/{a.n} random programs matched")
sys.exit(1 if bad else 0)
