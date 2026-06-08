//------------------------------------------------------------------------------
// tb_regfile.v — Testbench for Register File module
//------------------------------------------------------------------------------
// 测试目标：
//   1. 验证读写功能（写入后读出一致）
//   2. 验证 x0 恒为零（写入被忽略）
//   3. 验证写使能控制（we3=0 时不写入）
//   4. 验证同时读写（写优先或旧值，取决于设计）
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_regfile;

    reg         clk;
    reg         rst_n;

    // 读端口
    reg  [4:0]  a1, a2;
    wire [31:0] rd1, rd2;

    // 写端口
    reg  [4:0]  a3;
    reg         we3;
    reg  [31:0] wd3;

    // DUT 实例化
    regfile u_regfile (
        .clk  (clk),
        .rst_n(rst_n),
        .a1   (a1),
        .rd1  (rd1),
        .a2   (a2),
        .rd2  (rd2),
        .a3   (a3),
        .we3  (we3),
        .wd3  (wd3)
    );

    // 时钟生成 (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // 波形输出
    initial begin
        $dumpfile("tb_regfile.vcd");
        $dumpvars(0, tb_regfile);
    end

    // 测试主流程
    initial begin
        $display("===== Register File Testbench =====");

        // 1. 复位
        rst_n = 0; we3 = 0;
        #20 rst_n = 1;

        // 2. 测试基本读写：写 x5 = 0xDEADBEEF
        @(negedge clk);
        a3 = 5'd5; wd3 = 32'hDEADBEEF; we3 = 1;
        @(negedge clk);
        we3 = 0;
        a1 = 5'd5;
        #10;
        $display("Write/Read x5: rd1 = %h (expected DEADBEEF) %s",
                 rd1, (rd1 === 32'hDEADBEEF) ? "PASS" : "FAIL");

        // 3. 测试写 x10 = 42
        @(negedge clk);
        a3 = 5'd10; wd3 = 32'd42; we3 = 1;
        @(negedge clk);
        we3 = 0;
        a1 = 5'd10;
        #10;
        $display("Write/Read x10: rd1 = %0d (expected 42) %s",
                 rd1, (rd1 == 32'd42) ? "PASS" : "FAIL");

        // 4. 测试 x0 不可写
        @(negedge clk);
        a3 = 5'd0; wd3 = 32'hCAFEBABE; we3 = 1;
        @(negedge clk);
        we3 = 0;
        a1 = 5'd0;
        #10;
        $display("x0 read: rd1 = %h (expected 00000000) %s",
                 rd1, (rd1 === 32'b0) ? "PASS" : "FAIL");

        // 5. 测试双端口读
        @(negedge clk);
        a3 = 5'd7; wd3 = 32'd100; we3 = 1;    // x7 = 100
        @(negedge clk);
        a3 = 5'd8; wd3 = 32'd200; we3 = 1;    // x8 = 200
        @(negedge clk);
        we3 = 0;
        a1 = 5'd7; a2 = 5'd8;
        #10;
        $display("Dual read: rd1=%0d rd2=%0d (expected 100,200) %s",
                 rd1, rd2,
                 (rd1 == 32'd100 && rd2 == 32'd200) ? "PASS" : "FAIL");

        // 6. 验证 x5 和 x10 仍保持原值（未被后续写污染）
        a1 = 5'd5; a2 = 5'd10;
        #10;
        $display("Persistence: x5=%h x10=%0d %s",
                 rd1, rd2,
                 (rd1 === 32'hDEADBEEF && rd2 == 32'd42) ? "PASS" : "FAIL");

        // 7. 测试 we3=0 时不写入
        @(negedge clk);
        a3 = 5'd10; wd3 = 32'd999; we3 = 0;   // 不该写入
        @(negedge clk);
        a1 = 5'd10;
        #10;
        $display("Write-disable: x10=%0d (expected 42, not 999) %s",
                 rd1, (rd1 == 32'd42) ? "PASS" : "FAIL");

        #20 $display("===== Register File Testbench Complete =====");
        $finish;
    end

endmodule
