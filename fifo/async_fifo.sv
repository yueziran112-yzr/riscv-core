// Parameterized asynchronous FIFO (Cummings style): Gray-coded pointers + 2-flop synchronizers.
module async_fifo #(
  parameter int DW = 8,  //   DW : data width
  parameter int AW = 4  //   AW : address width (depth = 2**AW, AW >= 2)
) (
  // write domain
  input  logic          wclk, wrst_n,
  input  logic          winc,  // from outside: write increment signal
  input  logic [DW-1:0] wdata,
  output logic          wfull,
  // read domain
  input  logic          rclk, rrst_n,
  input  logic          rinc,  // from outside: read increment signal
  output logic [DW-1:0] rdata,
  output logic          rempty
);
  logic [DW-1:0] mem [0:(1<<AW)-1]; // left shift 1 = 2**AW, to calculate depth of FIFO. mem is a [DW*depth] matrix 

  logic [AW:0] wbin, wgray, wbin_n, wgray_n;       // one extra MSB distinguishes full from empty
  logic [AW:0] rbin, rgray, rbin_n, rgray_n;
  logic [AW:0] wq1_rgray, wq2_rgray;               // read pointer synchronized into write domain
  logic [AW:0] rq1_wgray, rq2_wgray;               // write pointer synchronized into read domain
  logic        wfull_n, rempty_n;

  // ---------------- write side ----------------
  assign wbin_n  = wbin + {{AW{1'b0}}, (winc & ~wfull)};
  assign wgray_n = (wbin_n >> 1) ^ wbin_n;  // transfer binary to Gray code: right shift by 1, each bit XOR with previous bit

  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) begin wbin <= '0; wgray <= '0; end
    else         begin wbin <= wbin_n; wgray <= wgray_n; end

  always_ff @(posedge wclk)
    if (winc && !wfull) mem[wbin[AW-1:0]] <= wdata;

  // full detection
  assign wfull_n = (wgray_n == {~wq2_rgray[AW:AW-1], wq2_rgray[AW-2:0]});
  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) wfull <= 1'b0; else wfull <= wfull_n;

  always_ff @(posedge wclk or negedge wrst_n)
    if (!wrst_n) {wq2_rgray, wq1_rgray} <= '0; else {wq2_rgray, wq1_rgray} <= {wq1_rgray, rgray};

  // ---------------- read side ----------------
  assign rbin_n  = rbin + {{AW{1'b0}}, (rinc & ~rempty)};
  assign rgray_n = (rbin_n >> 1) ^ rbin_n;

  always_ff @(posedge rclk or negedge rrst_n)
    if (!rrst_n) begin rbin <= '0; rgray <= '0; end
    else         begin rbin <= rbin_n; rgray <= rgray_n; end

  assign rdata = mem[rbin[AW-1:0]]; // first-word fall-through（FWFT）: rdata is valid whenever rempty == 0.

  // empty detection
  assign rempty_n = (rgray_n == rq2_wgray);
  always_ff @(posedge rclk or negedge rrst_n)
    if (!rrst_n) rempty <= 1'b1; else rempty <= rempty_n;

  always_ff @(posedge rclk or negedge rrst_n)
    if (!rrst_n) {rq2_wgray, rq1_wgray} <= '0; else {rq2_wgray, rq1_wgray} <= {rq1_wgray, wgray};

`ifdef FORMAL
  // ===================== formal properties (only compiled with -DFORMAL) =====================
  localparam int DEPTH = 1 << AW;
  // environment: start in reset; the two resets are asserted/released together
  initial assume (!wrst_n && !rrst_n);
  always @* assume (wrst_n == rrst_n);

  // true occupancy from the two (unsynchronized) binary pointers, seen in the same global time step
  wire [AW:0] f_fill = wbin - rbin;

  always @* begin
    // 1) never overflows or underflows: occupancy stays within [0, DEPTH]
    assert (f_fill <= DEPTH);
    // 2) flags are conservative: truly full -> wfull, truly empty -> rempty
    if (wrst_n) begin
      if (f_fill == DEPTH) assert (wfull);
      if (f_fill == 0)     assert (rempty);
    end
    // 3) Gray pointers always match the binary pointers
    assert (wgray == ((wbin >> 1) ^ wbin));
    assert (rgray == ((rbin >> 1) ^ rbin));
    // reachability (the assertions above must not be vacuous)
    cover (wrst_n && wfull);
    cover (wrst_n && !rempty);
    cover (wrst_n && f_fill == 0 && rempty);
  end
`endif
endmodule
