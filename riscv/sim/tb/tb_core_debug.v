//==============================================================================
// tb_core_debug.v — Debug Testbench for Branch Logic
//==============================================================================
// 专用于调试 beq 指令的分支跳转行为。
// 分层探测 ALU zero、branch_taken、控制信号等关键内部信号。

`timescale 1ns / 1ps

module tb_core_debug;

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

    // 分层探测内部信号
    wire [31:0] alu_a, alu_b, alu_result;
    wire        alu_zero;
    wire [3:0]  alu_control;
    wire        branch, jump, jump_reg;
    wire [2:0]  funct3;
    wire        branch_taken_inner;
    wire [31:0] next_pc_inner;
    wire [31:0] rf_x3;

    assign alu_a        = u_core.alu_a;
    assign alu_b        = u_core.alu_b;
    assign alu_result   = u_core.alu_result;
    assign alu_zero     = u_core.alu_zero;
    assign alu_control  = u_core.alu_control;
    assign branch       = u_core.branch;
    assign jump         = u_core.jump;
    assign jump_reg     = u_core.jump_reg;
    assign funct3       = u_core.funct3;
    assign branch_taken_inner = u_core.branch_taken;
    assign next_pc_inner = u_core.next_pc;
    assign rf_x3        = u_core.u_regfile.rf[3];

    initial begin
        $dumpfile("tb_core_debug.vcd");
        $dumpvars(0, tb_core_debug);
    end

    integer cycle;

    initial begin
        for (integer i = 0; i < 256; i = i + 1) mem[i] = 32'b0;

        // 极简测试：仅 3 条指令
        // 0x00: addi x3, x0, 5    (先把 x3 设为已知值)
        // 0x04: beq  x3, x3, +8   (自己跟自己比，必跳)
        // 0x08: addi x5, x0, 99   (应被跳过!)
        // 0x0C: addi x6, x0, 42   (beq 目标)
        mem[0] = 32'h00500193;   // addi x3, x0, 5
        mem[1] = 32'h00318463;   // beq  x3, x3, +8 (offset=8→imm[4:1]=4→instr[11:8]=4)
        mem[2] = 32'h06300293;   // addi x5, x0, 99  (应被跳过)
        mem[3] = 32'h02a00313;   // addi x6, x0, 42  (beq 目标)

        $display("=========================================");
        $display("  BEQ Branch Debug Test");
        $display("=========================================");
        $display("");
        $display("  mem[0]=addi x3,x0,5  @ 0x00");
        $display("  mem[1]=beq x3,x3,+8 @ 0x04 → target 0x0C");
        $display("  mem[2]=addi x5,x0,99 @ 0x08 (SHOULD SKIP)");
        $display("  mem[3]=addi x6,x0,42 @ 0x0C (target)");
        $display("");

        rst_n = 0; cycle = 0;
        #12 rst_n = 1;  // 错开 posedge 避开竞争

        // 运行并逐周期监控
        for (cycle = 1; cycle <= 10; cycle = cycle + 1) begin
            @(posedge clk);  // 等 posedge 稳定
            #1;               // 等 1ns 让所有信号稳定
            $display("--- Cycle %0d (t=%0t) ---", cycle, $time);
            $display("  PC          = 0x%h", pc);
            $display("  instr       = 0x%h", instr);
            $display("  opcode      = 0b%b", instr[6:0]);
            $display("  funct3      = 0b%b", funct3);
            $display("  rf[x3]      = %0d (0x%h)", rf_x3, rf_x3);
            $display("  alu_a       = %0d", alu_a);
            $display("  alu_b       = %0d", alu_b);
            $display("  alu_control = 0b%b", alu_control);
            $display("  alu_result  = %0d", alu_result);
            $display("  alu_zero    = %b", alu_zero);
            $display("  branch      = %b", branch);
            $display("  branch_taken= %b", branch_taken_inner);
            $display("  next_pc     = 0x%h", next_pc_inner);
            $display("");
        end

        $display("Final rf[x3] = %0d", u_core.u_regfile.rf[3]);
        $display("Final rf[x5] = %0d (expected 0)", u_core.u_regfile.rf[5]);
        $display("Final rf[x6] = %0d (expected 42)", u_core.u_regfile.rf[6]);
        $display("");
        if (u_core.u_regfile.rf[5] == 0 && u_core.u_regfile.rf[6] == 42)
            $display("BEQ BRANCH: PASS");
        else
            $display("BEQ BRANCH: FAIL (x5=%0d, x6=%0d)",
                      u_core.u_regfile.rf[5], u_core.u_regfile.rf[6]);

        #20 $finish;
    end

endmodule
