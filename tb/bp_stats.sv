// Optional branch-prediction statistics (make ... STATS=1).
// Counts control-flow instructions leaving EX and pipeline redirects (= mispredictions).
// The hierarchical names below follow the reference pipeline; rename them to match YOUR design.
module bp_stats;
  longint cf = 0, mispred = 0;
  bit     done = 0;
  always @(posedge tb_top.clk) if (tb_top.rst_n && !done) begin
    if (tb_top.dut.idex_valid && !tb_top.dut.ex_stall &&
        (tb_top.dut.idex_is_branch || tb_top.dut.idex_is_jal || tb_top.dut.idex_is_jalr)) cf++;
    if (tb_top.dut.redirect) mispred++;
    if (tb_top.dmem_be != 0 && tb_top.dmem_addr == tb_top.tohost) begin
      done = 1;
      $display("BPSTAT branches+jumps=%0d mispredicted=%0d accuracy=%0.1f%%",
               cf, mispred, cf ? 100.0 * (cf - mispred) / cf : 0.0);
    end
  end
endmodule
bind tb_top bp_stats u_bp_stats();
