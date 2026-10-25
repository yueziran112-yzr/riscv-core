# Parameterized Asynchronous FIFO with Formal Verification

A dual-clock FIFO in SystemVerilog (Cummings style), verified with a scoreboard testbench
over several clock ratios and with an unbounded formal proof.

## Design

`async_fifo #(DW, AW)` — data width `DW`, depth `2**AW`, first-word fall-through read.

- **Gray-code pointers**: write and read pointers are `AW+1` bits; only the registered Gray
  value crosses the clock domain, so a synchronized pointer is always either the old or the
  new value, never a corrupted mix of bits.
- **2-FF synchronizers** in each direction (read pointer → write domain, write pointer → read domain).
- **Full / empty**: the extra MSB tells "same position" from "one lap ahead".
  - empty (read domain): next read Gray pointer == synchronized write pointer
  - full (write domain): next write Gray pointer == synchronized read pointer with the two MSBs inverted
- Flags are **conservative**: each side sees a slightly old pointer of the other side, so it can
  only under-report free space or data, never over-report it.

## Verification 1 — scoreboard simulation (`make sim`)

Random write/read traffic, a SystemVerilog queue as reference model, incrementing data
(loss, duplication and reordering are all detected), and a check that each Gray pointer
changes by at most one bit per cycle. DW = 16, AW = 3 (depth 8), 20000 words per configuration.

| Write period | Read period | Write prob. | Read prob. | Result | Full cycles | Empty cycles | Max fill |
|---|---|---|---|---|---|---|---|
| 10 | 10 | 50% | 50% | PASS | 4567 | 4478 | 8/8 |
| 10 | 14 | 70% | 70% | PASS | 11264 | 199 | 8/8 |
| 7 | 29 | 90% | 90% | PASS | 69552 | 22 | 8/8 |
| 29 | 7 | 90% | 90% | PASS | 0 | 70061 | 2/8 |
| 10 | 10 | 100% | 100% | PASS | 0 | 22 | 5/8 |
| 10 | 10 | 100% | 10% | PASS | 178610 | 22 | 8/8 |
| 10 | 10 | 10% | 100% | PASS | 0 | 182544 | 5/8 |

Observation: with equal clocks and a read and a write every cycle, the FIFO still fills up to
5 entries. This is the pointer-synchronization round trip — the reader learns about new data
only two read cycles later — and shows why the depth must cover this latency.

## Verification 2 — formal proof (`make formal`, SymbiYosys)

Properties in `async_fifo.sv` (under `` `ifdef FORMAL``), proven for **all** input sequences
with two independent free-running clocks (`multiclock on`, engine `abc pdr`, AW = 2):

1. occupancy `wbin - rbin` never exceeds the depth → no overflow, no underflow
2. truly full → `wfull`; truly empty → `rempty`
3. Gray pointers always equal `bin ^ (bin >> 1)`

- **cover**: full, non-empty and empty states are all reachable, so the proof is not vacuous.
- **bmc**: bounded check (16 steps) as a second engine.
- **Mutation check**: making the full test identical to the empty test (`wgray_n == wq2_rgray`)
  makes the proof fail immediately.

## Assumptions and limitations

- Both resets are asserted and released together (`assume (wrst_n == rrst_n)`); a real design
  would add a reset synchronizer (async assert, sync release) per clock domain.
- The depth must be a power of two.
- The proof is run for AW = 2; the logic is identical for larger AW.

## How to run

```bash
make sim      # Icarus Verilog, 7 configurations
make formal   # SymbiYosys: prove, cover, bmc
```
