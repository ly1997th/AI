//------------------------------------------------------------------------------
// pc.v — Program Counter (程序计数器)
//------------------------------------------------------------------------------
// 功能：
//   1. 存储当前指令地址 (PC)
//   2. 每个时钟周期更新 PC = next_pc
//   3. 复位时 PC = 0 (或 RESET_VECTOR)
//
// 接口：
//   clk, rst_n    — 时钟与异步复位（低有效）
//   next_pc[31:0] — 下一指令地址
//   pc[31:0]      — 当前指令地址（输出）
//------------------------------------------------------------------------------

module pc #(
    parameter RESET_VECTOR = 32'h0000_0000   // 复位后起始地址
) (
    input  wire        clk,
    input  wire        rst_n,                // 异步复位，低有效
    input  wire [31:0] next_pc,
    output reg  [31:0] pc
);

    // TODO: 实现 PC 寄存器
    // 提示：
    //   always @(posedge clk or negedge rst_n)
    //      if (!rst_n) pc <= RESET_VECTOR;
    //      else        pc <= next_pc;

endmodule
