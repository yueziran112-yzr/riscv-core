# riscv-core starter kit (verification + measurement infrastructure)

Everything EXCEPT the RTL: testbenches, golden-vector generator, riscv-tests environment,
random program generator, trace comparison, C runtime, benchmarks, profiler, synthesis
wrapper, Booth reference model and the async-FIFO testbench.
Your RTL goes in rtl/core/ (see rtl/core/README.md) and fifo/async_fifo.sv.

    make unit                               # leaf-module unit tests
    make muldiv MUL_IMPL=n                  # multiplier / divider unit test
    make tests CORE=rtl/core/riscv_sc.sv    # riscv-tests on the single-cycle core
    make tests                              # riscv-tests on the pipeline
    make random N=100                       # pipeline vs single-cycle, random programs
    make bench MUL_IMPL=n BP=n              # C benchmarks: cycles / CPI
    make hello                              # run sw/c/hello.c
    make synth MUL_IMPL=n [LIB=...]         # Yosys synthesis (see synth/README.md)
    make -C fifo sim | formal               # async FIFO project

Environment (see the manual, chapter 1):  `cad` to load OSS CAD Suite, and
CROSS=riscv-none-elf-, RISCV_TESTS=$HOME/riscv-tests in ~/.zshrc.
