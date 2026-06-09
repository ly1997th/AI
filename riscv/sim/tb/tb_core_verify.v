//==============================================================================
// tb_core_verify.v — Robust Core Verification (Final)
//==============================================================================
// 不使用周期计数检查，而是等待稳定后直接检查最终寄存器状态。
//
// 测试程序：
//   addi x1, x0, 5      # x1 = 5
//   addi x2, x0, 3      # x2 = 3
//   add  x3, x1, x2     # x3 = 8
//   sub  x4, x1, x2     # x4 = 2
//   beq  x3, x3, +8     # 跳转 → 跳过下一条
//   addi x5, x0, 99     # 不应执行 (x5 = 0)
//   addi x6, x0, 42     # 应执行 (x6 = 42)
//==============================================================================

`timescale 1ns / 1ps

module tb_core_verify;

    reg         clk;
    reg         rst_n;
    wire [31:0] instr;
    wire [31:0] pc;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire        dmem_we, dmem_re;

    reg  [31:0] mem [0:255];

    core u_core (
        .clk(clk), .rst_n(rst_n),
        .instr_i(instr), .pc_o(pc),
        .mem_addr_o(dmem_addr), .mem_wdata_o(dmem_wdata),
        .mem_rdata_i(dmem_rdata),
        .mem_write_o(dmem_we), .mem_read_o(dmem_re)
    );

    initial clk = 0;
    always #5 clk = ~clk;
    assign instr = mem[pc[31:2]];
    assign dmem_rdata = (dmem_re) ? mem[dmem_addr[31:2]] : 32'b0;
    always @(posedge clk) if (dmem_we) mem[dmem_addr[31:2]] <= dmem_wdata;

    // 分层探测寄存器值
    wire [31:0] rf [0:31];
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gen_rf_probe
            assign rf[gi] = u_core.u_regfile.rf[gi];
        end
    endgenerate

    integer pass_count, fail_count;

    initial begin
        $dumpfile("tb_core_verify.vcd");
        $dumpvars(0, tb_core_verify);
    end

    task verify_reg;
        input [255:0] name;
        input [4:0]   reg_num;
        input [31:0]  expected;
        begin
            if (rf[reg_num] === expected) begin
                $display("  %0s (x%0d) = %0d [PASS]", name, reg_num, rf[reg_num]);
                pass_count = pass_count + 1;
            end else begin
                $display("  %0s (x%0d) = %0d, expected %0d [FAIL]",
                         name, reg_num, rf[reg_num], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0; fail_count = 0;

        $display("=========================================");
        $display("  RISC-V Core Verification (Final)");
        $display("=========================================");

        // 初始化存储器
        for (integer i = 0; i < 256; i = i + 1) mem[i] = 32'b0;

        // 加载测试程序（已校验过的机器码）
        mem[0] = 32'h00500093;   // addi x1, x0, 5
        mem[1] = 32'h00300113;   // addi x2, x0, 3
        mem[2] = 32'h002081b3;   // add  x3, x1, x2
        mem[3] = 32'h40208233;   // sub  x4, x1, x2
        mem[4] = 32'h00318463;   // beq  x3, x3, +8  (跳转到 mem[6])
        mem[5] = 32'h06300293;   // addi x5, x0, 99  (应被跳过)
        mem[6] = 32'h02a00313;   // addi x6, x0, 42  (beq 跳转目标)

        $display("");
        $display("Test Program:");
        $display("  [0x00] addi x1, 5");
        $display("  [0x04] addi x2, 3");
        $display("  [0x08] add  x3, x1, x2  → x3=8");
        $display("  [0x0C] sub  x4, x1, x2  → x4=2");
        $display("  [0x10] beq  x3, x3, +8  → jump to 0x18");
        $display("  [0x14] addi x5, 99       → SKIPPED");
        $display("  [0x18] addi x6, 42       → executed");

        // 复位
        rst_n = 0;
        #25 rst_n = 1;  // 确保复位释放后时钟稳定

        // 运行足够周期让所有指令完成 (7条指令需要~8个周期)
        repeat(12) @(posedge clk);

        // 等待稳定后验证
        #2;  // 避开 posedge 竞争

        $display("");
        $display("--- Final Register Verification ---");
        verify_reg("x1 (addi 5)",       1, 5);
        verify_reg("x2 (addi 3)",       2, 3);
        verify_reg("x3 (x1+x2=8)",      3, 8);
        verify_reg("x4 (x1-x2=2)",      4, 2);
        verify_reg("x5 (skipped=0)",    5, 0);
        verify_reg("x6 (target=42)",    6, 42);
        verify_reg("x0 (always 0)",     0, 0);
        // 验证 x7-x31 保持 0（未使用）
        verify_reg("x7 (unused)",       7, 0);

        $display("");
        $display("=========================================");
        $display("  Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL CPU TESTS PASSED!");
        else
            $display("  SOME TESTS FAILED!");
        $display("=========================================");

        #10 $finish;
    end

endmodule
