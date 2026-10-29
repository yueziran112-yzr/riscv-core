# Timing constraints for riscv_core (Cadence Genus). Units: ns.
# Start at 10 ns, then tighten (8, 6, ...) until the worst slack is close to 0.
create_clock -name clk -period 10.0 [get_ports clk]

# The instruction and data memories are outside the core: assume the outside world
# already uses 2 ns of each cycle on the way in and on the way out.
set_input_delay  2.0 -clock clk [get_ports {imem_rdata* dmem_rdata*}]
set_output_delay 2.0 -clock clk [all_outputs]

# rst_n is asynchronous: do not time it as a data path
set_false_path -from [get_ports rst_n]
