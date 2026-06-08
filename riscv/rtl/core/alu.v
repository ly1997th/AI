//------------------------------------------------------------------------------
// alu.v — Arithmetic Logic Unit (算术逻辑单元)
//------------------------------------------------------------------------------
// 功能：
//   执行 RV32I 所需的全部算术和逻辑运算，纯组合逻辑
//
// 接口：
//   a[31:0], b[31:0] — 两个操作数
//   alu_control[3:0]  — 操作选择
//   result[31:0]      — 运算结果
//   zero              — 结果为零标志（用于分支判断）
//
// ALU 操作码定义（ALUOp + funct3/funct7 → alu_control）：
//   0000: ADD    result = a + b
//   0001: SUB    result = a - b
//   0010: AND    result = a & b
//   0011: OR     result = a | b
//   0100: XOR    result = a ^ b
//   0101: SLL    result = a << b[4:0]
//   0110: SRL    result = a >> b[4:0]
//   0111: SRA    result = $signed(a) >>> b[4:0]
//   1000: SLT    result = ($signed(a) < $signed(b)) ? 1 : 0
//   1001: SLTU   result = (a < b) ? 1 : 0
//   1010: LUI    result = b                      (b = imm << 12)
//   1011: JAL/JALR/Branch result = 32'b0          (不需要ALU结果)
//
// 设计要点：
//   - 使用 always @(*) 或 assign 实现组合逻辑
//   - $signed() 系统函数用于有符号比较
//   - zero 输出 = (result == 0)，用于 BEQ/BNE 判断
//------------------------------------------------------------------------------

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);

    // TODO: 实现 ALU 组合逻辑
    // 提示：
    //   always @(*) begin
    //       case (alu_control)
    //           4'b0000: result = a + b;
    //           4'b0001: result = a - b;
    //           4'b0010: result = a & b;
    //           ... (补全所有操作)
    //           default: result = 32'b0;
    //       endcase
    //   end
    //   assign zero = (result == 32'b0);

endmodule
