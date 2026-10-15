`timescale 1ns/1ps
// Compare muldiv_unit (any MUL_IMPL) against the combinational reference muldiv_comb.
// Works for latency 0 (combinational: done in the start cycle) and multi-cycle units.
//   build with: -GMUL_IMPL=3   (0 comb, 1 radix-2 left, 2 radix-2 right, 3 Booth r4, 4 pipelined)
module tb_muldiv #(parameter int MUL_IMPL = 1);
  logic clk = 0, rst_n = 0;  always #5 clk = ~clk;
  logic start = 0, idle, done;  logic [2:0] f3;  logic [31:0] a, b, result, ref_y, got;
  muldiv_unit #(.MUL_IMPL(MUL_IMPL)) dut (.clk, .rst_n, .start, .f3, .a, .b, .idle, .done, .result);
  muldiv_comb ref_m (.a, .b, .f3, .y(ref_y));

  int errors = 0, n = 0, lat, lat_mul = -1, lat_div = -1;
  logic [31:0] edge_v [8] = '{0, 1, 32'hFFFF_FFFF, 32'h8000_0000, 32'h7FFF_FFFF, 2, 32'hFFFF_FFFE, 32'h0000_FFFF};

  task automatic run_one(input [2:0] f, input [31:0] x, input [31:0] y);
    logic [31:0] exp;
    f3 = f; a = x; b = y;
    @(negedge clk);
    while (!idle) @(negedge clk);
    start = 1; #1;
    exp = ref_y;
    lat = 0;
    if (done) got = result;                       // combinational unit: result in the start cycle
    else begin
      @(negedge clk); start = 0;
      lat = 1;
      while (!done && lat < 100) begin #1; if (done) break; @(negedge clk); lat++; end
      #1; got = result;
    end
    start = 0;
    n++;
    if (!done || got !== exp) begin
      errors++;
      if (errors < 10) $display("FAIL f3=%0d a=%h b=%h got=%h exp=%h done=%0d", f, x, y, got, exp, done);
    end
    if (!f[2] && lat_mul < 0) lat_mul = lat;
    if ( f[2] && lat_div < 0) lat_div = lat;
  endtask

  initial begin
    repeat (3) @(negedge clk); rst_n = 1;
    for (int f = 0; f < 8; f++) begin
      for (int i = 0; i < 8; i++) for (int j = 0; j < 8; j++) run_one(f[2:0], edge_v[i], edge_v[j]);
      for (int k = 0; k < 300; k++) run_one(f[2:0], $urandom, $urandom);
    end
    $display("MUL_IMPL=%0d: mul extra cycles=%0d, div extra cycles=%0d", MUL_IMPL, lat_mul, lat_div);
    if (errors == 0) $display("tb_muldiv: PASS (%0d ops)", n); else $display("tb_muldiv: FAIL (%0d/%0d)", errors, n);
    $finish;
  end
endmodule
