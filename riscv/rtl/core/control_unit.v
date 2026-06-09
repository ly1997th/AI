//==============================================================================
// control_unit.v — 控制单元 (Control Unit)
//==============================================================================
//
// 【电路架构】
// ┌──────────────────────────────────────────────────────────────┐
// │  功能：两级译码结构 — 主译码器（opcode→控制信号）+              │
// │        ALU译码器（ALUOp+funct→alu_control）                    │
// │                                                              │
// │  结构拓扑（2级译码树）：                                        │
// │                                                              │
// │  ┌─→ ┌──────────────┐                                        │
// │  │   │  主译码器     │                                        │
// │  │   │              │  reg_write, alu_src, mem_write,         │
// │  │   │  opcode[6:0] │  mem_read, mem_to_reg, branch,          │
// │  │   │     ↓        │  jump, jump_reg, alu_op[1:0]            │
// │  │   │  7:10 Decoder│                                        │
// │  │   └──────────────┘                                        │
// │  │                                                           │
// │  │   ┌──────────────────────────────────┐                    │
// │  └─→ │  ALU 译码器                       │                    │
// │      │                                  │                    │
// │      │  alu_op[1:0] ─┐                  │                    │
// │      │  funct3[2:0] ─┤                  │                    │
// │      │  funct7_5    ─┘                  │                    │
// │      │              ↓                   │                    │
// │      │  组合 LUT（3级选择树）            │──→ alu_control[3:0] │
// │      └──────────────────────────────────┘                    │
// │                                                              │
// │  路径分离分析（本模块纯控制通路，无数据/地址通路）：              │
// │    - 控制通路-第一级：opcode(7-bit) → 9路独立输出（主译码器）   │
// │    - 控制通路-第二级：{alu_op,funct3,funct7_5}(6-bit)          │
// │                      → alu_control(4-bit)（ALU译码器）        │
// │    - 所有输出均为控制信号，位宽≤1，扇出至数据通路的各模块        │
// │    - 无重汇聚风险：两级译码器间仅 alu_op 传递                   │
// │    - 关键路径：opcode→主译码→alu_op→ALU译码→alu_control        │
// │               ≈ 2级译码器深度，极短                             │
// └──────────────────────────────────────────────────────────────┘
//
// 【宏单元映射与PPA评估】
// ┌──────────────────────────────────────────────────────────────┐
// │  宏单元清单：                                                  │
// │    · 1× 7:10 Decoder（主译码器：opcode → 9个输出 + ALUOp）     │
// │    · 1× 组合 LUT（ALU译码器：6-bit in → 4-bit out）            │
// │                                                              │
// │  互联关系：                                                    │
// │    · opcode → 主译码器（扇出=1，内部自包含）                     │
// │    · funct3/funct7_5 → ALU译码器（扇出=1）                    │
// │    · reg_write → regfile.we3（扇出=1）                        │
// │    · alu_src → core中的ALU src MUX（扇出=1）                 │
// │    · branch → core中的PC next逻辑（扇出=1）                    │
// │    · alu_control[3:0] → alu（扇出=1，4-bit）                  │
// │    · 所有控制信号扇出均极小，无缓冲需求                          │
// │                                                              │
// │  PPA评估（精度分级：低敏感度—基于逻辑分析）：                     │
// │    · 面积：主译码器(~50门) + ALU译码LUT(~30门) ≈ 80门当量       │
// │            控制逻辑通常仅占处理器总面积的 1-3%                   │
// │    · 时序：2级译码 ≈ 2-3 级逻辑门延迟，远非关键路径              │
// │    · 功耗：极低（纯组合逻辑，无时钟节点）                         │
// │    · 工艺依赖：译码器面积在不同工艺下变化极小（以门为单位稳定）    │
// └──────────────────────────────────────────────────────────────┘
//
// 【RTL代码】
//==============================================================================

module control_unit (
    // ---- 主译码器输入 ----
    input  wire [6:0]  opcode,
    // ---- 主译码器输出 ----
    output reg         reg_write,
    output reg         alu_src,
    output reg         mem_write,
    output reg         mem_read,
    output reg         mem_to_reg,
    output reg         branch,
    output reg         jump,
    output reg         jump_reg,
    output reg  [1:0]  alu_op,

    // ---- ALU 译码器输入 ----
    input  wire [2:0]  funct3,
    input  wire        funct7_5,     // funct7[30] / funct7[5]
    // ---- ALU 译码器输出 ----
    output reg  [3:0]  alu_control
);

    //==========================================================================
    // 第一级译码：主译码器（7:10 Decoder）
    // opcode[6:0] → 9 根控制信号 + alu_op
    //==========================================================================
    always @(*) begin
        // 默认值（无效指令 / ecall / ebreak → 全部清零，安全状态）
        {reg_write, alu_src, mem_write, mem_read, mem_to_reg, branch, jump, jump_reg} = 8'b0;
        alu_op = 2'b00;

        case (opcode)
            // R-type (0110011): ALU 寄存器-寄存器运算
            7'b0110011: begin
                reg_write = 1'b1;
                // alu_src=0: ALU 第二操作数来自 rs2
                // mem_to_reg=0: 写回数据来自 ALU 结果
                alu_op    = 2'b10;   // 使用 funct3+funct7 进一步译码
            end

            // I-type ALU (0010011): ALU 立即数运算
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;    // ALU 第二操作数来自立即数
                alu_op    = 2'b11;   // 使用 funct3 进一步译码(I-type)
            end

            // Load (0000011): 从内存读取
            7'b0000011: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;    // 地址 = rs1 + imm
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;    // 写回数据来自内存
                alu_op     = 2'b00;   // ALU 做加法（计算地址）
            end

            // Store (0100011): 写入内存
            7'b0100011: begin
                alu_src   = 1'b1;     // 地址 = rs1 + imm
                mem_write = 1'b1;
                alu_op    = 2'b00;    // ALU 做加法（计算地址）
            end

            // Branch (1100011): 条件分支
            7'b1100011: begin
                branch = 1'b1;
                alu_op = 2'b01;       // ALU 做减法（比较 rs1, rs2）
            end

            // JAL (1101111): 无条件跳转并链接
            7'b1101111: begin
                reg_write = 1'b1;
                jump      = 1'b1;
            end

            // JALR (1100111): 间接跳转并链接
            7'b1100111: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;     // 计算跳转目标 = rs1 + imm
                jump_reg  = 1'b1;
                alu_op    = 2'b00;    // ALU 做加法
            end

            // LUI (0110111): 加载高位立即数
            7'b0110111: begin
                reg_write = 1'b1;
            end

            // AUIPC (0010111): PC 加高位立即数
            7'b0010111: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;    // ALU 做加法
            end

            default: begin
                // 无效 opcode：全部控制信号保持默认 0（安全状态）
            end
        endcase
    end

    //==========================================================================
    // 第二级译码：ALU 译码器（组合 LUT）
    // {alu_op[1:0], funct3[2:0], funct7_5} → alu_control[3:0]
    //==========================================================================
    always @(*) begin
        case (alu_op)
            // ALUOp=00: 加法（Load/Store/JALR/AUIPC 地址计算）
            2'b00: alu_control = 4'b0000;  // ADD

            // ALUOp=01: 减法（Branch 比较）
            2'b01: alu_control = 4'b0001;  // SUB

            // ALUOp=10: R-type — funct3 + funct7_5 联合译码
            2'b10: begin
                case ({funct7_5, funct3})
                    {1'b0, 3'b000}: alu_control = 4'b0000;  // ADD
                    {1'b1, 3'b000}: alu_control = 4'b0001;  // SUB
                    {1'b0, 3'b001}: alu_control = 4'b0101;  // SLL
                    {1'b0, 3'b010}: alu_control = 4'b1000;  // SLT
                    {1'b0, 3'b011}: alu_control = 4'b1001;  // SLTU
                    {1'b0, 3'b100}: alu_control = 4'b0100;  // XOR
                    {1'b0, 3'b101}: alu_control = 4'b0110;  // SRL
                    {1'b1, 3'b101}: alu_control = 4'b0111;  // SRA
                    {1'b0, 3'b110}: alu_control = 4'b0011;  // OR
                    {1'b0, 3'b111}: alu_control = 4'b0010;  // AND
                    default:        alu_control = 4'b0000;  // 安全默认
                endcase
            end

            // ALUOp=11: I-type ALU — 仅 funct3 译码（funct7_5 仅移位用）
            2'b11: begin
                case ({funct7_5, funct3})
                    {1'b0, 3'b000}: alu_control = 4'b0000;  // ADDI
                    {1'b0, 3'b010}: alu_control = 4'b1000;  // SLTI
                    {1'b0, 3'b011}: alu_control = 4'b1001;  // SLTIU
                    {1'b0, 3'b100}: alu_control = 4'b0100;  // XORI
                    {1'b0, 3'b110}: alu_control = 4'b0011;  // ORI
                    {1'b0, 3'b111}: alu_control = 4'b0010;  // ANDI
                    {1'b0, 3'b001}: alu_control = 4'b0101;  // SLLI
                    {1'b0, 3'b101}: alu_control = 4'b0110;  // SRLI
                    {1'b1, 3'b101}: alu_control = 4'b0111;  // SRAI
                    default:        alu_control = 4'b0000;  // 安全默认
                endcase
            end

            default: alu_control = 4'b0000;  // 安全默认
        endcase
    end

endmodule
