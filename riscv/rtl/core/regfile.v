//------------------------------------------------------------------------------
// regfile.v — Register File (寄存器文件)
//------------------------------------------------------------------------------
// 功能：
//   1. 包含 32 个 32-bit 通用寄存器 (x0–x31)
//   2. 2 个读端口（rs1, rs2）+ 1 个写端口（rd）
//   3. x0 硬件实现为恒零：
//      - 读出时：若地址 == 0，返回 0 而不是 reg[0]
//      - 写入时：若写地址 == 0，忽略写入
//
// 接口：
//   a1[4:0], a2[4:0]  — 读地址（rs1, rs2 的寄存器编号）
//   rd1[31:0], rd2[31:0] — 读数据（组合输出，无时钟延迟）
//   a3[4:0]   — 写地址（rd 的寄存器编号）
//   we3        — 写使能（RegWrite 控制信号）
//   wd3[31:0]  — 写数据
//
// 设计要点：
//   - 读操作用组合逻辑（assign 或 always @(*)），实现零延迟读取
//   - 写操作在时钟上升沿（always @(posedge clk)）
//   - x0 不可写：if (we3 && a3 != 5'b0) rf[a3] <= wd3;
//   - 读 x0 返回 0：assign rd1 = (a1 == 0) ? 0 : rf[a1];
//------------------------------------------------------------------------------

module regfile (
    input  wire        clk,
    input  wire        rst_n,
    // 读端口 1
    input  wire [4:0]  a1,      // rs1 地址
    output wire [31:0] rd1,     // rs1 数据
    // 读端口 2
    input  wire [4:0]  a2,      // rs2 地址
    output wire [31:0] rd2,     // rs2 数据
    // 写端口
    input  wire [4:0]  a3,      // rd 地址
    input  wire        we3,     // RegWrite
    input  wire [31:0] wd3      // 写数据
);

    // 32 个 32-bit 寄存器
    reg [31:0] rf [31:0];

    // TODO: 实现三端口寄存器文件
    // 提示 — 读：
    //   assign rd1 = (a1 == 5'b0) ? 32'b0 : rf[a1];
    //   assign rd2 = (a2 == 5'b0) ? 32'b0 : rf[a2];
    //
    // 提示 — 写：
    //   integer i;
    //   always @(posedge clk or negedge rst_n) begin
    //       if (!rst_n) begin
    //           for (i = 0; i < 32; i = i + 1) rf[i] <= 32'b0;
    //       end else if (we3 && a3 != 5'b0) begin
    //           rf[a3] <= wd3;
    //       end
    //   end

endmodule
