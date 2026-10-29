# Synthesis and timing baseline — 5-stage pipeline (MUL_IMPL=1, BP=0)

## Flow
Yosys 0.70 (OSS CAD Suite), `synth -flatten`, ABC mapping to SKY130 `sky130_fd_sc_hd`,
typical corner (tt, 25 °C, 1.8 V). No wire load, no clock tree, no I/O constraints,
no buffer insertion → absolute numbers are rough; **relative comparisons** within this flow
are what the multiplier and branch-prediction studies use.
A constrained Cadence Genus run is planned (scripts in `synth/core.sdc`, `synth/genus.tcl`).

## Whole core

| Metric | Value |
|---|---|
| Cells (generic gates) | 9578 |
| Flip-flops | 1818 (1024 in the register file) |
| Area (µm²) | 95 592 |
| ABC combinational delay | 14.87 ns |
| Estimated Fmax, 1 / (delay + 0.4 ns) | ≈ 65 MHz (0.4 ns = assumed clk-to-Q + setup) |
| Longest path in logic levels | 116 levels, multiplier `mcand` → 64-bit accumulator `acc` |

## Area breakdown (each module synthesized on its own)

| Module | Area (µm²) | Share | ABC delay |
|---|---|---|---|
| Register file (32 × 32 flip-flops, BYPASS=1) | 49 710 | 52 % | 7.758 ns |
| mul/div unit | 18 441 | 19 % | 9.309 ns |
|   — multiplier `mul_iter` (radix-2, 64-bit accumulator) | 10 915 | | 9.309 ns |
|   — divider `div_iter` (restoring) | 7 596 | | 4.791 ns |
| Rest (pipeline registers, decoder, ALU, forwarding, control) | ≈ 27 400 | 29 % | |

## Observations
- **Area**: half of the core is the register file, built from 1024 flip-flops and two 32:1 read
  multiplexers. A real chip would use a register-file macro from a memory compiler, which is much smaller.
- **Logic levels ≠ delay**: the path with the most logic levels is inside the multiplier (116 levels),
  but the multiplier alone has only 9.3 ns of delay while the whole core has 14.95 ns. The slowest path
  is therefore elsewhere. A static timing analysis of the same netlist (OpenSTA) shows it:
  `ifid_instr` rs1 field (fanout 584, register-file read mux) → load-use compare → bubble control
  (fanout 116) → ID/EX register. The delay is dominated by high-fanout nets, because Yosys does not
  insert buffers. A commercial tool (Genus) buffers these nets; the multiplier's 64-bit ripple-carry
  accumulator is then expected to become critical — to be checked with Genus.
- **Limitations**: typical corner only, no wires, no clock tree, no buffering, ABC default
  area/delay trade-off. Small differences between runs (a few cells) come from heuristic optimization;
  differences below ~15 % between two designs should not be over-interpreted.