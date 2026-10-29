# Cadence Genus synthesis of the 5-stage pipeline (riscv_core in riscv_pipe.sv).
# Run from the project root on the school machine:   genus -files synth/genus.tcl
# NOT tested by me (no license): check command names against the course lab and `help <cmd>`.

# ---- technology library: use the one given in the course (e.g. GPDK045 typical corner) ----
set_db init_lib_search_path /PATH/TO/COURSE/LIB          ;# <-- edit
set_db library              TYPICAL_CORNER.lib           ;# <-- edit

# ---- read RTL (do NOT read riscv_sc.sv: it also defines a module called riscv_core) ----
read_hdl -sv {
  rtl/core/regfile.sv rtl/core/imm_gen.sv rtl/core/alu.sv rtl/core/branch_cmp.sv
  rtl/core/lsu.sv rtl/core/decoder.sv
  rtl/core/mul_iter.sv rtl/core/div_iter.sv rtl/core/muldiv_unit.sv
  rtl/core/riscv_pipe.sv
}
elaborate riscv_core -parameters {{MUL_IMPL 1} {BP 0}}
check_design -unresolved

read_sdc synth/core.sdc

# ---- synthesis ----
syn_generic
syn_map
syn_opt

# ---- reports ----
file mkdir synth/genus
report_area                 > synth/genus/area.rpt
report_area -depth 2        > synth/genus/area_by_module.rpt
report_timing -max_paths 5  > synth/genus/timing.rpt
report_qor                  > synth/genus/qor.rpt
write_hdl                   > synth/genus/riscv_core_netlist.v
