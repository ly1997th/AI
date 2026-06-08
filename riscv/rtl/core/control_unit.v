//------------------------------------------------------------------------------
// control_unit.v — Control Unit (控制单元)
//------------------------------------------------------------------------------
// 功能：
//   译码指令 opcode，生成数据通路所需的全部控制信号
//
// 主译码器 (Main Decoder):
//   输入: opcode[6:0]
//   输出:
//     RegWrite   — 寄存器文件写使能 (R-type, I-ALU, Load, JAL, JALR, LUI, AUIPC)
//     ALUSrc     — ALU 第二操作数来源 (0=rs2, 1=立即数)
//     MemWrite   — 数据存储器写使能 (Store)
//     MemRead    — 数据存储器读使能 (Load)
//     MemtoReg   — 写回数据来源 (0=ALU结果, 1=内存数据)
//     Branch     — 分支指令标志 (用于 PC 更新逻辑)
//     Jump       — 无条件跳转标志 (JAL)
//     JumpReg    — 间接跳转标志 (JALR)
//     ALUOp[1:0] — ALU 操作类型编码，传递给 ALU 控制逻辑
//
// ALU 控制逻辑 (ALU Decoder):
//   输入: ALUOp[1:0] + funct3[2:0] + funct7[5]
//   输出: alu_control[3:0] (见 alu.v 的操作码定义)
//
//   编码规则:
//     ALUOp = 00: ALU 做加法 (用于 Load/Store/AUIPC)
//     ALUOp = 01: ALU 做减法 (用于分支比较)
//     ALUOp = 10: 根据 funct3 和 funct7 决定 R-type 操作
//     ALUOp = 11: 根据 funct3 决定 I-type 操作 (除移位外)
//
// 控制信号真值表 (见 refs/instructions-reference.md):
//
//   opcode     | RegWrite | ALUSrc | MemWrite | MemRead | MemtoReg | Branch | Jump | ALUOp
//   -----------|----------|--------|----------|---------|----------|--------|------|------
//   R-type     |    1     |   0    |    0     |    0    |    0     |   0    |  0   | 10
//   I-type ALU |    1     |   1    |    0     |    0    |    0     |   0    |  0   | 11
//   Load       |    1     |   1    |    0     |    1    |    1     |   0    |  0   | 00
//   Store      |    0     |   1    |    1     |    0    |    X     |   0    |  0   | 00
//   Branch     |    0     |   0    |    0     |    0    |    X     |   1    |  0   | 01
//   JAL        |    1     |   X    |    0     |    0    |    X     |   X    |  1   | XX
//   JALR       |    1     |   X    |    0     |    0    |    X     |   X    |  0*  | XX
//   LUI        |    1     |   X    |    0     |    0    |    X     |   0    |  0   | XX+
//   AUIPC      |    1     |   X    |    0     |    0    |    X     |   0    |  0   | XX+
//
//   * JALR 用 JumpReg 信号区分
//   + LUI/AUIPC 的 ALU 控制逻辑由顶层例外处理，或通过额外的 alu_control 码
//   X = don't care
//------------------------------------------------------------------------------

module control_unit (
    // 主译码器输入
    input  wire [6:0]  opcode,
    // 主译码器输出
    output reg         reg_write,
    output reg         alu_src,
    output reg         mem_write,
    output reg         mem_read,
    output reg         mem_to_reg,
    output reg         branch,
    output reg         jump,
    output reg         jump_reg,
    output reg  [1:0]  alu_op,

    // ALU 控制输入
    input  wire [2:0]  funct3,
    input  wire        funct7_5,     // funct7[30] / funct7[5]
    // ALU 控制输出
    output reg  [3:0]  alu_control
);

    //--------------------------------------------------------------------------
    // TODO: 实现主译码器
    //--------------------------------------------------------------------------
    // 提示：
    //   always @(*) begin
    //       case (opcode)
    //           7'b0110011: begin  // R-type
    //               reg_write = 1; alu_src = 0; mem_write = 0;
    //               mem_read = 0; mem_to_reg = 0; branch = 0;
    //               jump = 0; jump_reg = 0; alu_op = 2'b10;
    //           end
    //           7'b0010011: begin  // I-type ALU
    //               reg_write = 1; alu_src = 1; mem_write = 0;
    //               mem_read = 0; mem_to_reg = 0; branch = 0;
    //               jump = 0; jump_reg = 0; alu_op = 2'b11;
    //           end
    //           ... (补全其余 opcode)
    //           default: begin
    //               reg_write = 0; alu_src = 0; mem_write = 0;
    //               mem_read = 0; mem_to_reg = 0; branch = 0;
    //               jump = 0; jump_reg = 0; alu_op = 2'b00;
    //           end
    //       endcase
    //   end

    //--------------------------------------------------------------------------
    // TODO: 实现 ALU 控制逻辑
    //--------------------------------------------------------------------------
    // 提示：
    //   always @(*) begin
    //       case (alu_op)
    //           2'b00: alu_control = 4'b0000;  // ADD (用于 load/store/auipc)
    //           2'b01: alu_control = 4'b0001;  // SUB (用于分支比较)
    //           2'b10: begin  // R-type — 根据 funct3 + funct7
    //               case ({funct7_5, funct3})
    //                   {1'b0, 3'b000}: alu_control = 4'b0000;  // ADD
    //                   {1'b1, 3'b000}: alu_control = 4'b0001;  // SUB
    //                   {1'b0, 3'b001}: alu_control = 4'b0101;  // SLL
    //                   ... (补全其余 R-type 操作)
    //               endcase
    //           end
    //           2'b11: begin  // I-type ALU — 根据 funct3
    //               case (funct3)
    //                   3'b000: alu_control = 4'b0000;  // ADDI
    //                   3'b010: alu_control = 4'b1000;  // SLTI
    //                   ... (补全其余 I-type 操作)
    //               endcase
    //           end
    //       endcase
    //   end

endmodule
