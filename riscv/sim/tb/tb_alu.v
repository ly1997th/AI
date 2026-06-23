//==============================================================================
// tb_alu.v — ALU Testbench
//==============================================================================
// Tests: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU, zero_flag detection
//==============================================================================

`timescale 1ns / 1ps

module tb_alu;

  // Inputs
  reg  [31:0] opa;
  reg  [31:0] opb;
  reg  [3:0]  op_sel;

  // Outputs
  wire [31:0] dat;
  wire        zero_flag;

  // DUT
  alu u_alu
  (
    .opa       (opa),
    .opb       (opb),
    .op_sel    (op_sel),
    .dat       (dat),
    .zero_flag (zero_flag)
  );

  // Waveform
  initial
  begin
    $dumpfile("tb_alu.vcd");
    $dumpvars(0, tb_alu);
  end

  // Test flow
  initial
  begin
    $display("===== ALU Testbench =====");

    // --- ADD ---
    op_sel = 4'b0000;  // ADD
    opa = 10; opb = 5;
    #10 $display("ADD: %0d + %0d = %0d (expected 15) %s",
                  opa, opb, dat, (dat == 15) ? "PASS" : "FAIL");
    opa = 0; opb = 0;
    #10 $display("ADD: %0d + %0d = %0d (expected 0, zero=%b) %s",
                  opa, opb, dat, zero_flag,
                  (dat == 0 && zero_flag) ? "PASS" : "FAIL");
    opa = 32'hFFFFFFFF; opb = 1;
    #10 $display("ADD: %h + %0d = %h (expected 0, overflow) %s",
                  opa, opb, dat, (dat == 0) ? "PASS" : "FAIL");

    // --- SUB ---
    op_sel = 4'b0001;  // SUB
    opa = 10; opb = 3;
    #10 $display("SUB: %0d - %0d = %0d (expected 7) %s",
                  opa, opb, dat, (dat == 7) ? "PASS" : "FAIL");
    opa = 5; opb = 5;
    #10 $display("SUB: %0d - %0d = %0d (expected 0, zero=%b) %s",
                  opa, opb, dat, zero_flag, (zero_flag) ? "PASS" : "FAIL");

    // --- AND ---
    op_sel = 4'b0010;  // AND
    opa = 32'hFFFF0000; opb = 32'hFF00FF00;
    #10 $display("AND: %h & %h = %h (expected FF000000) %s",
                  opa, opb, dat, (dat == 32'hFF000000) ? "PASS" : "FAIL");

    // --- OR ---
    op_sel = 4'b0011;  // OR
    opa = 32'hFFFF0000; opb = 32'h0000FFFF;
    #10 $display("OR:  %h | %h = %h (expected FFFFFFFF) %s",
                  opa, opb, dat, (dat == 32'hFFFFFFFF) ? "PASS" : "FAIL");

    // --- XOR ---
    op_sel = 4'b0100;  // XOR
    opa = 32'hFFFFFFFF; opb = 32'hFFFFFFFF;
    #10 $display("XOR: %h ^ %h = %h (expected 0) %s",
                  opa, opb, dat, (dat == 0) ? "PASS" : "FAIL");

    // --- SLL ---
    op_sel = 4'b0101;  // SLL
    opa = 32'h1; opb = 4;
    #10 $display("SLL: %h << %0d = %h (expected 16) %s",
                  opa, opb[4:0], dat, (dat == 32'h10) ? "PASS" : "FAIL");

    // --- SRL ---
    op_sel = 4'b0110;  // SRL
    opa = 32'hF0000000; opb = 28;
    #10 $display("SRL: %h >> %0d = %h (expected F) %s",
                  opa, opb[4:0], dat, (dat == 32'hF) ? "PASS" : "FAIL");

    // --- SRA ---
    op_sel = 4'b0111;  // SRA
    opa = 32'h80000000; opb = 4;
    #10 $display("SRA: %h >>> %0d = %h (expected F8000000) %s",
                  opa, opb[4:0], dat, (dat == 32'hF8000000) ? "PASS" : "FAIL");

    // --- SLT (signed) ---
    op_sel = 4'b1000;  // SLT
    opa = -1; opb = 1;
    #10 $display("SLT: %0d < %0d = %0d (expected 1) %s",
                  $signed(opa), $signed(opb), dat, (dat == 1) ? "PASS" : "FAIL");
    opa = 5; opb = -3;
    #10 $display("SLT: %0d < %0d = %0d (expected 0) %s",
                  $signed(opa), $signed(opb), dat, (dat == 0) ? "PASS" : "FAIL");

    // --- SLTU (unsigned) ---
    op_sel = 4'b1001;  // SLTU
    opa = 32'hFFFFFFFF; opb = 1;
    #10 $display("SLTU: %h < %0d = %0d (expected 0) %s",
                  opa, opb, dat, (dat == 0) ? "PASS" : "FAIL");

    #10 $display("===== ALU Testbench Complete =====");
    $finish;
  end

endmodule
