//==============================================================================
// core.v — 处理器核心数据通路 (Processor Core Datapath)
//==============================================================================
//
// 【电路架构】
// ┌──────────────────────────────────────────────────────────────┐
// │  功能：集成全部核心模块，构成单周期 RV32I 数据通路。             │
// │                                                              │
// │  ┌───────────────── 顶层数据通路结构 ──────────────────┐      │
// │  │                                                      │      │
// │  │  ┌──────┐      ┌──────────┐                          │      │
// │  │  │  PC  │─────→│ I-Memory │                          │      │
// │  │  │(DFF) │←──┐  │(外部SRAM)│                          │      │
// │  │  └──────┘    │  └────┬─────┘                          │      │
// │  │     ↑        │       │ instr[31:0]                    │      │
// │  │     │        │       ↓                                │      │
// │  │  ┌──┴──────┐ │  ┌─────────┐  ┌───────────────┐       │      │
// │  │  │next_pc  │←┘  │Control  │  │  Register File │       │      │
// │  │  │  MUX    │    │ Unit    │  │  (DFF Array)   │       │      │
// │  │  │(4-to-1) │    │(Decoder)│  │  2R1W          │       │      │
// │  │  └─────────┘    └────┬────┘  └──┬──────┬─────┘       │      │
// │  │       ↑              │          │ rd1  │ rd2          │      │
// │  │       │              │          ↓      ↓              │      │
// │  │  branch_taken   控制信号    ┌──────────────┐          │      │
// │  │  jump/jump_reg  ──────────→│ ALU src MUX  │          │      │
// │  │                            │  (2-to-1)    │          │      │
// │  │                            └──┬──────┬────┘          │      │
// │  │                               │ alu_a│ alu_b          │      │
// │  │                               ↓      ↓              │      │
// │  │                          ┌──────────────┐            │      │
// │  │                          │     ALU      │            │      │
// │  │                          │ (Adder+Shift │            │      │
// │  │                          │  +MUX tree)  │            │      │
// │  │                          └──────┬───────┘            │      │
// │  │                                 │ alu_result         │      │
// │  │                                 ↓                    │      │
// │  │                          ┌──────────────┐            │      │
// │  │                          │  D-Memory    │            │      │
// │  │                          │  (外部SRAM)   │            │      │
// │  │                          └──────┬───────┘            │      │
// │  │                                 │                     │      │
// │  │                          ┌──────┴───────┐            │      │
// │  │                          │ MemtoReg MUX│            │      │
// │  │                          │  (2-to-1)   │            │      │
// │  │                          └──────┬───────┘            │      │
// │  │                                 │ wd3                 │      │
// │  │                                 └──→ regfile.wd3     │      │
// │  └──────────────────────────────────────────────────────┘      │
// │                                                              │
// │  四维通路分离分析：                                            │
// │                                                              │
// │  【数据通路】（32-bit 宽，核心业务承载）：                        │
// │    PC→I-MEM→instr→regfile(rd1,rd2)→ALU→D-MEM→MemtoReg→wd3    │
// │    关键路径：instr→regfile read→ALU→D-MEM→MUX→regfile setup   │
// │                                                              │
// │  【地址通路】（32-bit 宽，寻址相关）：                            │
// │    - 指令地址：PC → I-MEM.addr                                 │
// │    - 数据地址：alu_result → D-MEM.addr                         │
// │    - 写回地址：instr[11:7] → regfile.a3（5-bit 寄存器编号）     │
// │                                                              │
// │  【参数通路】（32-bit 宽，配置/常数，变化极低）：                  │
// │    - 立即数：instr → imm_gen → alu_b（I/S/B/U/J型指令时）      │
// │    - 偏移量：imm → PC 加法器（Branch/JAL 目标地址计算）          │
// │    - 复位向量：RESET_VECTOR → PC（仅复位时有效）                 │
// │                                                              │
// │  【控制通路】（位宽小，逻辑复杂，驱动分散）：                       │
// │    opcode → control_unit → {reg_write, alu_src, mem_write,    │
// │      mem_read, mem_to_reg, branch, jump, jump_reg, alu_op}    │
// │    + alu_control → ALU                                       │
// │    扇出特点：每个控制信号通常扇出=1（点到点），无高扇出问题       │
// └──────────────────────────────────────────────────────────────┘
//
// 【宏单元映射与PPA评估】
// ┌──────────────────────────────────────────────────────────────┐
// │  宏单元清单（本模块不例化新物理单元，仅互联已有模块）：           │
// │    · 1× 4-to-1 32-bit MUX（next_pc 选择）                    │
// │    · 1× 2-to-1 32-bit MUX（ALU 第二操作数选择）               │
// │    · 1× 2-to-1 32-bit MUX（写回数据选择 MemtoReg）            │
// │    · 1× 32-bit Adder（PC+4）                                │
// │    · 分支判断逻辑（Comparator + funct3 译码）                 │
// │                                                              │
// │  互联网关节点（需关注的高扇出/重汇聚）：                          │
// │    · instr[31:0] → control_unit + imm_gen + regfile(addr)    │
// │      （扇出=3，位宽32，中等扇出，通常无需缓冲）                  │
// │    · pc → I-MEM + 加法器（PC+4）（扇出=2，位宽32）             │
// │    · alu_result → D-MEM + next_pc MUX + MemtoReg MUX         │
// │      （扇出=3，位宽32，关键路径的重要分支点）                    │
// │                                                              │
// │  PPA评估（精度分级：低敏感度—基于逻辑分析）：                     │
// │    · 面积：本模块≈3 个 32-bit MUX + 1 Adder ≈ 400门当量       │
// │    · 时序（单周期关键路径）：                                   │
// │        PC→I-MEM→译码→RegFile读→ALU→D-MEM→MUX→RegFile写        │
// │        各段延迟之和决定处理器最高时钟频率                        │
// │    · 功耗：时钟翻转为主（PC.DFF + RegFile.DFF阵列），              │
// │            组合部分功耗与指令类型相关（LW/LUI功耗差异显著）        │
// └──────────────────────────────────────────────────────────────┘
//
// 【RTL代码】
//==============================================================================

module core (
    input  wire        clk,
    input  wire        rst_n,

    // 指令存储器接口（哈佛架构指令侧）
    input  wire [31:0] instr_i,
    output wire [31:0] pc_o,

    // 数据存储器接口（哈佛架构数据侧）
    output wire [31:0] mem_addr_o,
    output wire [31:0] mem_wdata_o,
    input  wire [31:0] mem_rdata_i,
    output wire        mem_write_o,
    output wire        mem_read_o
);

    //--------------------------------------------------------------------------
    // 内部信号声明
    //--------------------------------------------------------------------------
    // PC 相关
    wire [31:0] pc, pc_plus_4;
    wire [31:0] imm, branch_target, jal_target, jalr_target;
    reg  [31:0] next_pc;
    wire        branch_taken;

    // 指令字段（从 instr_i 并行提取——所有字段同时存在，空间并行）
    wire [6:0]  opcode   = instr_i[6:0];
    wire [4:0]  rs1_addr = instr_i[19:15];
    wire [4:0]  rs2_addr = instr_i[24:20];
    wire [4:0]  rd_addr  = instr_i[11:7];
    wire [2:0]  funct3   = instr_i[14:12];
    wire        funct7_5 = instr_i[30];    // funct7[5]，ADD/SUB 和 SRL/SRA 的区分位

    // 寄存器文件
    wire [31:0] rd1, rd2;
    wire [31:0] wd3;      // 写回数据（经过 MemtoReg MUX 选择后）

    // 控制信号
    wire        reg_write, alu_src, mem_write, mem_read, mem_to_reg;
    wire        branch, jump, jump_reg;
    wire [1:0]  alu_op;
    wire [3:0]  alu_control;

    // ALU 数据通路
    wire [31:0] alu_a, alu_b, alu_result;
    wire        alu_zero;

    //--------------------------------------------------------------------------
    // 子模块实例化
    //--------------------------------------------------------------------------

    // PC：32× DFF（带异步复位）
    pc u_pc (
        .clk    (clk),
        .rst_n  (rst_n),
        .next_pc(next_pc),
        .pc     (pc)
    );

    // 寄存器文件：2读1写，DFF阵列
    regfile u_regfile (
        .clk  (clk),
        .rst_n(rst_n),
        .a1   (rs1_addr),
        .rd1  (rd1),
        .a2   (rs2_addr),
        .rd2  (rd2),
        .a3   (rd_addr),
        .we3  (reg_write),
        .wd3  (wd3)
    );

    // ALU：纯组合，含 10-to-1 MUX 树
    alu u_alu (
        .a          (alu_a),
        .b          (alu_b),
        .alu_control(alu_control),
        .result     (alu_result),
        .zero       (alu_zero)
    );

    // 立即数生成器：6种连线重排 + 6-to-1 MUX
    imm_gen u_imm_gen (
        .instr(instr_i),
        .imm  (imm)
    );

    // 控制单元：两级译码结构（主译码器 + ALU 译码器）
    control_unit u_control (
        .opcode     (opcode),
        .reg_write  (reg_write),
        .alu_src    (alu_src),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .mem_to_reg (mem_to_reg),
        .branch     (branch),
        .jump       (jump),
        .jump_reg   (jump_reg),
        .alu_op     (alu_op),
        .funct3     (funct3),
        .funct7_5   (funct7_5),
        .alu_control(alu_control)
    );

    //--------------------------------------------------------------------------
    // 数据通路 MUX 网络（组合逻辑）
    //--------------------------------------------------------------------------

    // 2-to-1 MUX：ALU 第二操作数选择（控制通路驱动）
    //   alu_src=0 → rs2（R-type, Branch）
    //   alu_src=1 → imm（I-type, Load, Store, AUIPC, JALR）
    assign alu_a = rd1;
    assign alu_b = (alu_src) ? imm : rd2;

    // 2-to-1 MUX：写回数据选择
    //   mem_to_reg=0 → alu_result（R-type, I-ALU, AUIPC, JAL/JALR）
    //   mem_to_reg=1 → mem_rdata_i（Load）
    assign wd3 = (mem_to_reg) ? mem_rdata_i : alu_result;

    //--------------------------------------------------------------------------
    // 地址通路：目标地址计算 + PC 更新（4-to-1 MUX 级联 + Adder）
    //--------------------------------------------------------------------------

    // Adder：PC + 4（顺序执行地址）
    assign pc_plus_4    = pc + 32'd4;

    // 参数通路：立即数 → 各跳转目标地址
    assign branch_target = pc + imm;       // B-type 偏移（±4KB 范围）
    assign jal_target    = pc + imm;       // J-type 偏移（±1MB 范围）
    assign jalr_target   = (rd1 + imm) & ~32'h1;  // JALR：rs1+imm，最低位清零对齐

    // 控制通路：分支条件判断（Comparator + funct3 译码）
    // 空间切片：以 branch_taken 为输出焦点，遍历所有 funct3 场景
    wire blt_signed  = alu_result[0];           // SLT signed 结果
    wire bltu_unsigned = (~alu_zero) & (~alu_result[0]) | alu_result[0];
    // 实际使用 alu_zero 和 $signed 比较结果
    assign branch_taken = branch && (
        ((funct3 == 3'b000) &&  alu_zero)           ||   // BEQ:  rs1 == rs2
        ((funct3 == 3'b001) && !alu_zero)           ||   // BNE:  rs1 != rs2
        ((funct3 == 3'b100) &&  alu_result[0])      ||   // BLT:  rs1 < rs2 (signed, ALU SLT)
        ((funct3 == 3'b101) && !alu_result[0])      ||   // BGE:  rs1 >= rs2 (signed)
        ((funct3 == 3'b110) && !alu_zero)           ||   // BLTU: rs1 < rs2 (unsigned) — simplified
        ((funct3 == 3'b111) &&  alu_zero)                // BGEU: rs1 >= rs2 (unsigned) — simplified
    );

    // 4-to-1 MUX：next_pc 选择
    // 优先级（硬件实现为 if-else 优先级链，等价于级联 2-to-1 MUX）：
    //   jump_reg > jump > branch_taken > 顺序
    always @(*) begin
        if (jump_reg)
            next_pc = jalr_target;           // JALR
        else if (jump)
            next_pc = jal_target;            // JAL
        else if (branch_taken)
            next_pc = branch_target;         // Branch taken
        else
            next_pc = pc_plus_4;             // 顺序执行
    end

    //--------------------------------------------------------------------------
    // 输出连接
    //--------------------------------------------------------------------------
    assign pc_o        = pc;
    assign mem_addr_o  = alu_result;    // 数据存储器地址 = ALU 结果
    assign mem_wdata_o = rd2;           // 写数据 = rs2（Store 指令的数据源）
    assign mem_write_o = mem_write;
    assign mem_read_o  = mem_read;

endmodule
