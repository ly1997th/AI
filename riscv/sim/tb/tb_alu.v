//------------------------------------------------------------------------------
// tb_alu.v — Testbench for ALU module
//------------------------------------------------------------------------------
// 测试目标：
//   1. 验证所有 ALU 运算的正确性
//   2. 验证 zero 标志输出
//   3. 验证有符号/无符号运算的差异
//
// 测试用例覆盖：
//   - ADD, SUB（基础算术）
//   - AND, OR, XOR（逻辑运算）
//   - SLL, SRL, SRA（移位运算）
//   - SLT, SLTU（比较运算）
//   - 边界条件：零操作数、溢出、全1等
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_alu;

    // 输入
    reg  [31:0] a, b;
    reg  [3:0]  alu_control;

    // 输出
    wire [31:0] result;
    wire        zero;

    // DUT 实例化
    alu u_alu (
        .a          (a),
        .b          (b),
        .alu_control(alu_control),
        .result     (result),
        .zero       (zero)
    );

    // 波形输出
    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
    end

    // 测试主流程
    initial begin
        $display("===== ALU Testbench =====");

        // --- ADD 测试 ---
        alu_control = 4'b0000;  // ADD
        a = 10; b = 5;
        #10 $display("ADD: %0d + %0d = %0d (expected 15) %s",
                      a, b, result, (result == 15) ? "PASS" : "FAIL");
        a = 0; b = 0;
        #10 $display("ADD: %0d + %0d = %0d (expected 0, zero=%b) %s",
                      a, b, result, zero, (result == 0 && zero) ? "PASS" : "FAIL");
        a = 32'hFFFFFFFF; b = 1;
        #10 $display("ADD: %h + %0d = %h (expected 0, overflow) %s",
                      a, b, result, (result == 0) ? "PASS" : "FAIL");

        // --- SUB 测试 ---
        alu_control = 4'b0001;  // SUB
        a = 10; b = 3;
        #10 $display("SUB: %0d - %0d = %0d (expected 7) %s",
                      a, b, result, (result == 7) ? "PASS" : "FAIL");
        a = 5; b = 5;
        #10 $display("SUB: %0d - %0d = %0d (expected 0, zero=%b) %s",
                      a, b, result, zero, (zero) ? "PASS" : "FAIL");

        // --- AND 测试 ---
        alu_control = 4'b0010;  // AND
        a = 32'hFFFF0000; b = 32'hFF00FF00;
        #10 $display("AND: %h & %h = %h (expected FF000000) %s",
                      a, b, result, (result == 32'hFF000000) ? "PASS" : "FAIL");

        // --- OR 测试 ---
        alu_control = 4'b0011;  // OR
        a = 32'hFFFF0000; b = 32'h0000FFFF;
        #10 $display("OR:  %h | %h = %h (expected FFFFFFFF) %s",
                      a, b, result, (result == 32'hFFFFFFFF) ? "PASS" : "FAIL");

        // --- XOR 测试 ---
        alu_control = 4'b0100;  // XOR
        a = 32'hFFFFFFFF; b = 32'hFFFFFFFF;
        #10 $display("XOR: %h ^ %h = %h (expected 0) %s",
                      a, b, result, (result == 0) ? "PASS" : "FAIL");

        // --- SLL 测试 ---
        alu_control = 4'b0101;  // SLL
        a = 32'h1; b = 4;       // b[4:0] = 4
        #10 $display("SLL: %h << %0d = %h (expected 16) %s",
                      a, b[4:0], result, (result == 32'h10) ? "PASS" : "FAIL");

        // --- SRL 测试 ---
        alu_control = 4'b0110;  // SRL
        a = 32'hF0000000; b = 28;
        #10 $display("SRL: %h >> %0d = %h (expected F) %s",
                      a, b[4:0], result, (result == 32'hF) ? "PASS" : "FAIL");

        // --- SRA 测试 ---
        alu_control = 4'b0111;  // SRA
        a = 32'h80000000; b = 4; // 算术右移负数
        #10 $display("SRA: %h >>> %0d = %h (expected F8000000) %s",
                      a, b[4:0], result, (result == 32'hF8000000) ? "PASS" : "FAIL");

        // --- SLT 测试（有符号） ---
        alu_control = 4'b1000;  // SLT (signed)
        a = -1; b = 1;          // -1 < 1 (有符号)
        #10 $display("SLT: %0d < %0d = %0d (expected 1) %s",
                      $signed(a), $signed(b), result, (result == 1) ? "PASS" : "FAIL");
        a = 5; b = -3;          // 5 < -3? No
        #10 $display("SLT: %0d < %0d = %0d (expected 0) %s",
                      $signed(a), $signed(b), result, (result == 0) ? "PASS" : "FAIL");

        // --- SLTU 测试（无符号） ---
        alu_control = 4'b1001;  // SLTU (unsigned)
        a = 32'hFFFFFFFF; b = 1; // 无符号: 0xFFFFFFFF > 1
        #10 $display("SLTU: %h < %0d = %0d (expected 0) %s",
                      a, b, result, (result == 0) ? "PASS" : "FAIL");

        #10 $display("===== ALU Testbench Complete =====");
        $finish;
    end

endmodule
