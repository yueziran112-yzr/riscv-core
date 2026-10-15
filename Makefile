# ---------------------------------------------------------------------------------------
#  RV32IM pipeline project - top-level Makefile
#
#   make unit                         leaf-module unit tests (golden vectors)
#   make muldiv   [MUL_IMPL=n]        multiplier/divider unit test against the reference
#   make tests    [CORE=..] [MUL_IMPL=n] [BP=n]   riscv-tests rv32ui + rv32um
#   make random   [N=100]             random differential test: pipeline vs single-cycle
#   make bench    [MUL_IMPL=n] [BP=n] [STATS=1]  C benchmarks: cycles, instret, CPI (+ predictor stats)
#   make hello                        run sw/c/hello.c
#   make synth    [MUL_IMPL=n]        Yosys synthesis of the core (SKY130 if LIB is set)
#   make synth-mul MUL_TOP=mul_xxx    synthesize one multiplier module stand-alone
#   make clean
# ---------------------------------------------------------------------------------------
.PHONY: unit muldiv sim tests random bench hello synth synth-mul clean

RISCV_TESTS ?= $(HOME)/riscv-tests
CROSS       ?= riscv-none-elf-
CORE        ?= rtl/core/riscv_pipe.sv
MUL_IMPL    ?= 1
BP          ?= 0
N           ?= 30
LIB         ?=
export RISCV_TESTS CROSS

# every .sv in rtl/core except the cores themselves
RTL_LIB  = $(filter-out rtl/core/riscv_%.sv,$(wildcard rtl/core/*.sv))
STATS   ?=
CFG      = $(basename $(notdir $(CORE)))_m$(MUL_IMPL)_bp$(BP)$(if $(STATS),_stats)
OBJ     ?= obj/$(CFG)
SIM      = $(OBJ)/Vtb_top
VFLAGS   = --binary --timing --trace -Wno-fatal -Wno-WIDTH -Wno-UNOPTFLAT -O2 --top-module tb_top \
           -GMUL_IMPL=$(MUL_IMPL) -GBP=$(BP)

unit:
	python3 scripts/gen_vectors.py tb/vec
	@mkdir -p obj
	verilator --binary --timing -Wno-fatal -Wno-WIDTH --Mdir obj/unit --top-module tb_leaf \
	  tb/tb_leaf.sv rtl/core/regfile.sv rtl/core/imm_gen.sv rtl/core/alu.sv rtl/core/branch_cmp.sv rtl/core/lsu.sv >/dev/null
	./obj/unit/Vtb_leaf

muldiv:
	@mkdir -p obj
	verilator --binary --timing -Wno-fatal -Wno-WIDTH -GMUL_IMPL=$(MUL_IMPL) --Mdir obj/muldiv_m$(MUL_IMPL) \
	  --top-module tb_muldiv tb/tb_muldiv.sv $(RTL_LIB) >/dev/null
	./obj/muldiv_m$(MUL_IMPL)/Vtb_muldiv

sim: $(SIM)
$(SIM): tb/tb_top.sv $(RTL_LIB) $(CORE)
	@mkdir -p $(OBJ)
	verilator $(VFLAGS) --Mdir $(OBJ) tb/tb_top.sv $(if $(STATS),tb/bp_stats.sv) $(RTL_LIB) $(CORE) >/dev/null

tests: sim
	$(MAKE) -C sw
	python3 scripts/run_tests.py --sim $(SIM) --build sw/build

random:
	$(MAKE) sim CORE=rtl/core/riscv_sc.sv MUL_IMPL=0 BP=0 OBJ=obj/ref
	$(MAKE) sim
	python3 scripts/run_random.py --n $(N) --ref-sim obj/ref/Vtb_top --dut-sim $(SIM)

bench: sim
	$(MAKE) -C sw/bench
	python3 scripts/run_bench.py --sim $(SIM) --build sw/bench/build

CFLAGS_C = -march=rv32im -mabi=ilp32 -O2 -nostdlib -nostartfiles -ffreestanding -T sw/c/link.ld -Wl,--no-warn-rwx-segments
hello: sim
	$(CROSS)gcc $(CFLAGS_C) sw/c/crt0.S sw/c/hello.c -o sw/c/hello.elf -lgcc
	$(CROSS)objcopy -O binary sw/c/hello.elf sw/c/hello.bin
	python3 scripts/bin2hex.py sw/c/hello.bin sw/c/hello.hex
	$(SIM) +HEX=sw/c/hello.hex +TOHOST=$$($(CROSS)nm sw/c/hello.elf | awk '$$3=="tohost"{print $$1}') +TIMEOUT=5000000

synth:
	python3 scripts/synth.py --top riscv_core --files $(RTL_LIB) $(CORE) --param MUL_IMPL=$(MUL_IMPL) --param BP=$(BP) \
	  $(if $(LIB),--lib $(LIB)) --tag core_$(CFG)

MUL_TOP ?= mul_iter
synth-mul:
	python3 scripts/synth.py --top $(MUL_TOP) --files $(RTL_LIB) $(if $(LIB),--lib $(LIB)) --tag $(MUL_TOP)

clean:
	rm -rf obj sw/build sw/build_rand sw/bench/build sw/c/*.elf sw/c/*.bin sw/c/*.hex synth/out wave.vcd
