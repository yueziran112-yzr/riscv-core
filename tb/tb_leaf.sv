`timescale 1ns/1ps
// Unit test for regfile / imm_gen / alu / branch_cmp / lsu against Python golden vectors.
module tb_leaf;
  logic        clk = 0;
  always #5 clk = ~clk;
  int errors = 0, checks = 0;

  // ---------- DUTs ----------
  logic [31:0] instr, imm;               imm_gen   u_imm (.instr, .imm);
  logic [31:0] a, b, y;  logic [3:0] op; alu       u_alu (.a, .b, .op, .y);
  logic [2:0]  f3b;      logic taken;    branch_cmp u_br (.a, .b, .funct3(f3b), .taken);
  logic [2:0]  lf3, sf3; logic [1:0] llo, slo; logic [31:0] rword, rdata, swd_in, swd_out; logic [3:0] be;
  lsu_load  u_ld (.funct3(lf3), .addr_lo(llo), .rword, .rdata);
  lsu_store u_st (.funct3(sf3), .addr_lo(slo), .wdata_in(swd_in), .wdata_out(swd_out), .be);

  logic we; logic [4:0] ra1, ra2, wa; logic [31:0] wd, rd1, rd2;
  regfile #(.BYPASS(1'b1)) u_rf (.clk, .we, .ra1, .ra2, .wa, .wd, .rd1, .rd2);

  task automatic check(input string what, input logic [31:0] got, input logic [31:0] exp);
    checks++;
    if (got !== exp) begin errors++; if (errors < 15) $display("FAIL %s: got %h exp %h", what, got, exp); end
  endtask

  int fd, n;
  logic [31:0] v0, v1, v2, v3, v4, v5, v6;

  initial begin
    // ---- imm_gen ----
    fd = $fopen("tb/vec/imm.txt", "r");
    while ($fscanf(fd, "%h %h\n", v0, v1) == 2) begin instr = v0; #1; check("imm_gen", imm, v1); end
    $fclose(fd);
    // ---- alu ----
    fd = $fopen("tb/vec/alu.txt", "r");
    while ($fscanf(fd, "%h %h %h %h\n", v0, v1, v2, v3) == 4) begin
      op = v0[3:0]; a = v1; b = v2; #1; check($sformatf("alu op%0d", v0), y, v3); end
    $fclose(fd);
    // ---- branch ----
    fd = $fopen("tb/vec/br.txt", "r");
    while ($fscanf(fd, "%h %h %h %h\n", v0, v1, v2, v3) == 4) begin
      f3b = v0[2:0]; a = v1; b = v2; #1; check($sformatf("br f3=%0d", v0), {31'b0, taken}, v3); end
    $fclose(fd);
    // ---- lsu ----
    fd = $fopen("tb/vec/lsu.txt", "r");
    while ($fscanf(fd, "%h %h %h %h %h %h %h\n", v0, v1, v2, v3, v4, v5, v6) == 7) begin
      lf3 = v0[2:0]; llo = v1[1:0]; rword = v2; sf3 = v4[2:0]; slo = v5[1:0]; swd_in = v2; #1;
      check($sformatf("load f3=%0d lo=%0d", v0, v1), rdata, v3);
      check("store be", {28'b0, be}, v6);
      for (int i = 0; i < 4; i++)
        if (be[i]) check($sformatf("store lane%0d", i), {24'b0, swd_out[8*i +: 8]}, {24'b0, v2[8*(i - slo) +: 8]});
    end
    $fclose(fd);
    // ---- regfile ----
    we = 1; wa = 5'd5; wd = 32'hDEADBEEF; ra1 = 5'd5; ra2 = 5'd0; #1;
    check("rf bypass", rd1, 32'hDEADBEEF); check("rf x0", rd2, 0);          // same-cycle bypass, x0 = 0
    @(posedge clk); #1; we = 0; check("rf read after write", rd1, 32'hDEADBEEF);
    we = 1; wa = 5'd0; wd = 32'h12345678; ra1 = 5'd0; @(posedge clk); #1; we = 0; check("rf x0 write ignored", rd1, 0);

    if (errors == 0) $display("tb_leaf: PASS (%0d checks)", checks);
    else             $display("tb_leaf: FAIL (%0d errors / %0d checks)", errors, checks);
    $finish;
  end
endmodule
