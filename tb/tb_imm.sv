// Quick standalone test for imm_gen: real instructions, immediates checked by hand.
module tb_imm;
  logic [31:0] instr, imm;
  int errors = 0;
  imm_gen dut (.instr, .imm);

  task automatic check(string asm, logic [31:0] code, logic [31:0] exp);
    instr = code; #1;
    if (imm !== exp) begin
      $display("FAIL  %-22s instr %h  imm %h  expected %h", asm, code, imm, exp);
      errors++;
    end else
      $display("ok    %-22s imm %h", asm, imm);
  endtask

  initial begin
    check("addi x1,x0,5",      32'h00500093, 32'h0000_0005);   // I, positive
    check("addi x1,x0,-1",     32'hFFF00093, 32'hFFFF_FFFF);   // I, negative
    check("lw x2,-4(x1)",      32'hFFC0A103, 32'hFFFF_FFFC);   // I (load)
    check("jalr x0,8(x1)",     32'h00808067, 32'h0000_0008);   // I (jalr)
    check("sw x2,12(x1)",      32'h0020A623, 32'h0000_000C);   // S, positive
    check("sw x2,-8(x1)",      32'hFE20AC23, 32'hFFFF_FFF8);   // S, negative
    check("beq x1,x2,+16",     32'h00208863, 32'h0000_0010);   // B, positive
    check("bne x1,x2,-4",      32'hFE209EE3, 32'hFFFF_FFFC);   // B, negative
    check("blt x1,x2,+2048",   32'h0020C063 | 32'h80, 32'h0000_0800); // B, bit 11 (instr[7])
    check("lui x1,0x12345",    32'h123450B7, 32'h1234_5000);   // U
    check("auipc x1,0xFFFFF",  32'hFFFFF097, 32'hFFFF_F000);   // U
    check("jal x1,+2048",      32'h001000EF, 32'h0000_0800);   // J, bit 11 (instr[20])
    check("jal x0,-8",         32'hFF9FF06F, 32'hFFFF_FFF8);   // J, negative
    check("jal x1,+0x1000",    32'h000010EF, 32'h0000_1000);   // J, bits 19:12
    if (errors == 0) $display("imm_gen: PASS");
    else             $display("imm_gen: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
