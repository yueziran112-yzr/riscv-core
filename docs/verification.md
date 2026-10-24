# Verification of the 5-stage pipeline

## Layer 1 – riscv-tests
`make tests`: 48/48 (rv32ui + rv32um)

## Layer 2 – random differential testing
`make random N=60`: 60/60 programs match the single-cycle reference, commit by commit.

## Layer 3 – mutation testing
Each mutant is one deliberate bug in `riscv_pipe.sv`.

| # | Injected bug | riscv-tests | random (N=10) | Caught? |
|---|---|---|---|---|
| M1 | no load-use stall | 42/48 | 0/10 | yes (both) |
| M2 | no MEM/WB → EX forwarding (rs1) | 2/48 | 0/10 | yes (both) |
| M3 | no EX/MEM → EX forwarding (rs2) | 2/48 | 0/10 | yes (both) |
| M4 | no register-file bypass | 0/48 | 0/10 | yes (both) |
| M5 | jalr redirects but does not flush | 47/48 | 0/10 | yes — riscv-tests only 1 failure |
| M6 | forwarding ignores rd = x0 | 48/48 | 1/10 | random only |
| M7 | ID/EX bubble ignores ex_stall | 48/48 | 10/10 | no — equivalent mutant |
| M8 | forwarding priority reversed (rs1) | 0/48 | 0/10 | yes (both) |
| M9 | store data not forwarded | 43/48 | 5/10 | yes (both) |

## Observations
- **The two test suites complement each other.** M5 (jalr does not flush) is a serious bug,
  but only 1 of the 48 riscv-tests fails; every random program catches it.
  M6 (x0 forwarded) passes all riscv-tests and is caught only by the random generator's
  "write x0, then read x0" pattern.
- **Some bugs are only caught occasionally.** M9 (store data not forwarded) fails 5 of 10
  random programs: it needs a store right after the instruction that produces its data.
- **M7 is an equivalent mutant, not a test hole.** While a mul/div waits in EX, `redirect`
  and `load_use` cannot be 1 (EX holds the mul/div, not a branch or a load), and IF/ID holds
  the next instruction, which is valid. So the bubble condition is never true during
  `ex_stall`, and `!ex_stall` is redundant protection in this design. Confirmed with 150
  random programs and all C benchmarks.