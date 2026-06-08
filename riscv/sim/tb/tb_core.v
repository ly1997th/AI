//------------------------------------------------------------------------------
// tb_core.v — Testbench for Processor Core (全系统测试)
//------------------------------------------------------------------------------
// 测试目标：
//   1. 运行一个简单的 RISC-V 汇编程序
//   2. 验证每一条指令在单周期数据通路中的正确性
//   3. 验证程序计数器的顺序执行和跳转
//
// 测试程序（RV32I 汇编 → 手工汇编为机器码）：
//   addi x1, x0, 5      # x1 = 5
//   addi x2, x0, 3      # x2 = 3
//   add  x3, x1, x2     # x3 = x1 + x2 = 8
//   sub  x4, x1, x2     # x4 = x1 - x2 = 2
//   beq  x3, x3, +8     # 应该跳转（x3 == x3）
//   addi x5, x0, 99     # 不应执行（已被分支跳过）
//   addi x6, x0, 42     # x6 = 42（跳转目标，beq 跳到这里）
//
// 机器码（手工汇编）：
//   addi x1, x0, 5  → 0x00500093 (I-type, rd=x1=00001, rs1=x0=00000, imm=5, funct3=000)
//   addi x2, x0, 3  → 0x00300113
//   add  x3, x1, x2 → 0x002081b3
//   sub  x4, x1, x2 → 0x40208233
//   beq  x3, x3, +8 → 0x00318263 (offset = +8 bytes = +2 instructions)
//   addi x5, x0, 99 → 0x06300293
//   addi x6, x0, 42 → 0x02a00313
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module tb_core;

    reg         clk;
    reg         rst_n;

    // 指令存储器接口
    wire [31:0] instr;
    reg  [31:0] pc;

    // 数据存储器接口
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_we;
    wire        dmem_re;

    // 简易存储器（仿真用）
    reg  [31:0] mem [0:255];

    // DUT 实例化
    core u_core (
        .clk         (clk),
        .rst_n       (rst_n),
        .instr_i     (instr),
        .pc_o        (pc),
        .mem_addr_o  (dmem_addr),
        .mem_wdata_o (dmem_wdata),
        .mem_rdata_i (dmem_rdata),
        .mem_write_o (dmem_we),
        .mem_read_o  (dmem_re)
    );

    // 时钟生成
    initial clk = 0;
    always #10 clk = ~clk;  // 周期 20ns

    // 指令存储器读取（组合逻辑）
    assign instr = mem[pc[31:2]];

    // 数据存储器读写
    assign dmem_rdata = (dmem_re) ? mem[dmem_addr[31:2]] : 32'b0;
    always @(posedge clk) begin
        if (dmem_we)
            mem[dmem_addr[31:2]] <= dmem_wdata;
    end

    // 波形输出
    initial begin
        $dumpfile("tb_core.vcd");
        $dumpvars(0, tb_core);
    end

    // 测试主流程
    initial begin
        $display("===== Core Testbench (Single-Cycle) =====");

        // 初始化存储器
        for (integer i = 0; i < 256; i = i + 1)
            mem[i] = 32'b0;

        // 加载测试程序到存储器
        // TODO: 修正这些机器码的手工汇编（以下只是占位符，需要根据实际指令格式核实）
        mem[0] = 32'h00500093;   // 0x000: addi x1, x0, 5   (rd=x1=00001, rs1=x0=00000, imm=5, funct3=000, opcode=0010011)
        mem[1] = 32'h00300113;   // 0x004: addi x2, x0, 3   (rd=x2=00010, rs1=x0=00000, imm=3)
        mem[2] = 32'h002081b3;   // 0x008: add  x3, x1, x2  (rd=x3=00011, rs1=x1=00001, rs2=x2=00010, funct3=000, funct7=0000000)
        mem[3] = 32'h40208233;   // 0x00c: sub  x4, x1, x2  (rd=x4=00100, funct7=0100000)
        mem[4] = 32'h00318263;   // 0x010: beq  x3, x3, +8  (rs1=x3=00011, rs2=x3=00011, offset=8)
        mem[5] = 32'h06300293;   // 0x014: addi x5, x0, 99  (不应执行)
        mem[6] = 32'h02a00313;   // 0x018: addi x6, x0, 42  (期望执行)

        // 复位
        rst_n = 0;
        #30 rst_n = 1;

        // 运行 10 个周期
        #200;

        $display("Simulation finished. Check waveform (tb_core.vcd).");
        $display("Expected final state: x1=5, x2=3, x3=8, x4=2, x5=0, x6=42");
        $finish;
    end

endmodule
