`timescale 1ns/1ps
// Self-checking testbench with scoreboard, random traffic and coverage counters.
// Run several clock ratios:  -GWPER=.. -GRPER=.. -GWPROB=.. -GRPROB=..
module tb_async_fifo #(
  parameter int DW = 16, parameter int AW = 3,
  parameter int WPER = 10, parameter int RPER = 14,        // clock periods (ns)
  parameter int WPROB = 50, parameter int RPROB = 50,      // % chance of trying to write / read each cycle
  parameter int NWORDS = 20000, parameter int SEED = 1
);
  logic wclk = 0, rclk = 0, wrst_n = 0, rrst_n = 0;
  always #(WPER/2.0) wclk = ~wclk;
  always #(RPER/2.0) rclk = ~rclk;

  logic winc = 0, rinc = 0, wfull, rempty;  logic [DW-1:0] wdata, rdata;
  async_fifo #(.DW(DW), .AW(AW)) dut (.wclk, .wrst_n, .winc, .wdata, .wfull, .rclk, .rrst_n, .rinc, .rdata, .rempty);

  // ---------------- scoreboard ----------------
  logic [DW-1:0] q [$];
  int n_wr = 0, n_rd = 0, errors = 0;
  int cov_full = 0, cov_empty = 0, cov_simul = 0, max_fill = 0;
  logic [DW-1:0] cnt = 16'h1;
  int seed_w = SEED, seed_r = SEED + 100;

  // write driver: drive after the edge, sample "accepted" at the edge
  always @(posedge wclk) begin
    if (wrst_n) begin
      if (winc && !wfull) begin q.push_back(wdata); n_wr++; cnt <= cnt + 1; end
      if (q.size() > max_fill) max_fill = q.size();
      if (wfull) cov_full++;
      winc  <= (n_wr < NWORDS) && ($urandom_range(99) < WPROB);
      wdata <= cnt + ((winc && !wfull) ? 1 : 0);
    end
  end
  // read side checker
  always @(posedge rclk) begin
    if (rrst_n) begin
      if (rinc && !rempty) begin
        logic [DW-1:0] exp;
        if (q.size() == 0) begin errors++; $display("FAIL: read from empty scoreboard at %0t", $time); end
        else begin
          exp = q.pop_front();
          if (rdata !== exp) begin errors++; if (errors < 10) $display("FAIL: data got %h exp %h at %0t", rdata, exp, $time); end
        end
        n_rd++;
      end
      if (rempty) cov_empty++;
      if (rinc && !rempty && winc && !wfull) cov_simul++;
      rinc <= $urandom_range(99) < RPROB;
    end
  end

  // ---------------- extra checks (assertion-style) ----------------
  logic [AW:0] wgray_prev, rgray_prev;
  function automatic int popcnt(input logic [AW:0] v); popcnt = 0; for (int i = 0; i <= AW; i++) popcnt += v[i]; endfunction
  always @(posedge wclk) if (wrst_n) begin
    if (popcnt(dut.wgray ^ wgray_prev) > 1) begin errors++; $display("FAIL: write Gray pointer changed >1 bit"); end
    wgray_prev <= dut.wgray;
  end
  always @(posedge rclk) if (rrst_n) begin
    if (popcnt(dut.rgray ^ rgray_prev) > 1) begin errors++; $display("FAIL: read Gray pointer changed >1 bit"); end
    rgray_prev <= dut.rgray;
  end

  initial begin
    wgray_prev = 0; rgray_prev = 0; wdata = 1;
    #(3*WPER) wrst_n = 1; #(2*RPER) rrst_n = 1;
    wait (n_rd == NWORDS);
    #(20*RPER);
    if (q.size() != 0) begin errors++; $display("FAIL: %0d words left in scoreboard", q.size()); end
    $display("tb_async_fifo W=%0d R=%0d wp=%0d rp=%0d : %s  words=%0d full_cyc=%0d empty_cyc=%0d simul=%0d max_fill=%0d/%0d",
             WPER, RPER, WPROB, RPROB, (errors == 0) ? "PASS" : "FAIL", n_rd, cov_full, cov_empty, cov_simul, max_fill, 1 << AW);
    $finish;
  end
  initial begin #(500000000) $display("TIMEOUT"); $finish; end
endmodule
