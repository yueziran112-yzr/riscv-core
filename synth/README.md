# Synthesis

Generic gates (no technology library):

    make synth MUL_IMPL=1            # whole core
    make synth-mul MUL_TOP=mul_iter  # one multiplier on its own

SKY130 standard cells (area in um^2 + ABC delay estimate). Download the typical-corner
liberty file once (about 13 MB) into this folder:

    curl -L -o synth/sky130_fd_sc_hd__tt_025C_1v80.lib \
      https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/master/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

then add  LIB=synth/sky130_fd_sc_hd__tt_025C_1v80.lib  to the make command.
Results are appended to synth/out/summary.csv.
