// Quick standalone test for regfile only.
module tb_rf;
  logic clk = 0;  always #5 clk = ~clk;
  logic we;  logic [4:0] ra1, ra2, wa;  logic [31:0] wd, rd1, rd2;
  int errors = 0;

  regfile #(.BYPASS(1'b0)) dut (.clk, .we, .ra1, .ra2, .wa, .wd, .rd1, .rd2);

  task automatic check(string what, logic [31:0] got, logic [31:0] exp);
    if (got !== exp) begin
      $display("FAIL  %-28s got %h  expected %h", what, got, exp);
      errors++;
    end else
      $display("ok    %-28s %h", what, got);
  endtask

  task automatic write(logic [4:0] a, logic [31:0] d);
    @(negedge clk); we = 1; wa = a; wd = d;
    @(negedge clk); we = 0;
  endtask

  initial begin
    we = 0; wa = 0; wd = 0; ra1 = 0; ra2 = 0;
    write(5'd1, 32'h1111_1111);
    write(5'd2, 32'h2222_2222);
    write(5'd31, 32'hDEAD_BEEF);
    write(5'd0, 32'hFFFF_FFFF);            // writing x0 must be ignored
    #1;
    ra1 = 1;  ra2 = 2;  #1;
    check("read x1 on port 1", rd1, 32'h1111_1111);
    check("read x2 on port 2", rd2, 32'h2222_2222);
    ra1 = 31; ra2 = 31; #1;
    check("read x31 on both ports", rd1, 32'hDEAD_BEEF);
    check("  (port 2)", rd2, 32'hDEAD_BEEF);
    ra1 = 0;  #1;
    check("x0 stays 0 after write", rd1, 32'h0);
    write(5'd1, 32'hABCD_0001);            // overwrite
    ra1 = 1; #1;
    check("overwrite x1", rd1, 32'hABCD_0001);
    @(negedge clk); we = 0; wa = 2; wd = 32'h9999_9999;  // we=0: no write
    @(negedge clk); ra2 = 2; #1;
    check("we=0 does not write", rd2, 32'h2222_2222);
    if (errors == 0) $display("regfile: PASS");
    else             $display("regfile: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
