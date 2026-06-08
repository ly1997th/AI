//------------------------------------------------------------------------------
// imm_gen.v — Immediate Generator (立即数生成器)
//------------------------------------------------------------------------------
// 功能：
//   从 32-bit 指令中提取立即数，并做符号扩展至 32-bit
//
// 输入：
//   instr[31:0] — 当前指令
// 输出：
//   imm[31:0]   — 符号扩展后的立即数
//
// 六种指令格式的立即数构造方式：
//
//   I-type (addi, lw, jalr):
//     imm = {{20{instr[31]}}, instr[31:20]}
//     位布局: instr[31] 符号位, instr[30:20] 立即数值
//
//   S-type (sw, sh, sb):
//     imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}
//     位布局: instr[31:25]=imm[11:5], instr[11:7]=imm[4:0]
//
//   B-type (beq, bne, blt, bge, bltu, bgeu):
//     imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}
//     位布局: 隐式最低位为 0（16-bit 对齐），不需要 instr[7] 的最低位
//     NOTE: 实际是 {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
//
//   U-type (lui, auipc):
//     imm = {instr[31:12], 12'b0}
//     位布局: instr[31:12] 是 20-bit 立即数的高位
//
//   J-type (jal):
//     imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}
//     位布局: 同样隐式最低位为 0
//
// 设计要点：
//   - 不需要"知道"指令类型，只需根据 opcode 对号入座
//   - {N{bit}} 是 Verilog 的复制操作符（replication operator）
//   - B-type 和 J-type 的最低位置 0（16-bit 对齐，地址为偶数）
//------------------------------------------------------------------------------

module imm_gen (
    input  wire [31:0] instr,   // 指令机器码
    output reg  [31:0] imm      // 符号扩展后的 32-bit 立即数
);

    // TODO: 实现立即数生成器
    // 提示 — 根据 opcode 选择不同的提取方式：
    //   wire [6:0] opcode = instr[6:0];
    //   always @(*) begin
    //       case (opcode)
    //           7'b0010011, 7'b0000011, 7'b1100111:  // I-type
    //               imm = {{20{instr[31]}}, instr[31:20]};
    //           7'b0100011:  // S-type
    //               imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    //           7'b1100011:  // B-type
    //               imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    //           7'b0110111, 7'b0010111:  // U-type
    //               imm = {instr[31:12], 12'b0};
    //           7'b1101111:  // J-type
    //               imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    //           default: imm = 32'b0;
    //       endcase
    //   end

endmodule
