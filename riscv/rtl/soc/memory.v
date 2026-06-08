//------------------------------------------------------------------------------
// memory.v — Unified Memory (统一存储器)
//------------------------------------------------------------------------------
// 功能：
//   仿真用的统一指令/数据存储器（冯·诺依曼架构）。
//   注意：这仅用于仿真！实际 FPGA/ASIC 中会用分离的 I-MEM 和 D-MEM。
//
// 接口：
//   clk         — 时钟
//   i_addr[31:0] — 指令地址（来自 PC）
//   i_rdata[31:0] — 指令数据（输出）
//   d_addr[31:0] — 数据地址（来自 ALU 结果）
//   d_wdata[31:0] — 数据写数据（来自 rs2）
//   d_rdata[31:0] — 数据读数据（输出）
//   d_we         — 数据写使能
//   d_re         — 数据读使能
//
// 存储器尺寸：
//   MEM_DEPTH  — 存储器深度（word 数），默认 1024
//   MEM_WIDTH  — 每个 word 的字节数，默认 4 (32-bit)
//
// 设计要点：
//   - 用 Verilog reg 数组模拟 SRAM
//   - 组合逻辑读（assign 或 always @(*)）：i_rdata = mem[i_addr >> 2]
//   - 时序逻辑写（always @(posedge clk)）：if (d_we) mem[d_addr >> 2] <= d_wdata;
//   - 地址按 word 对齐，低 2 位忽略（或可添加非对齐访问检查）
//   - 仿真时可在此模块中预加载测试程序（用 $readmemh）
//------------------------------------------------------------------------------

module memory #(
    parameter MEM_DEPTH = 1024,        // word 数
    parameter MEM_WIDTH = 4            // 字节数/word
) (
    input  wire        clk,

    // 指令端口（只读）
    input  wire [31:0] i_addr,
    output reg  [31:0] i_rdata,

    // 数据端口（读/写）
    input  wire [31:0] d_addr,
    input  wire [31:0] d_wdata,
    output reg  [31:0] d_rdata,
    input  wire        d_we,
    input  wire        d_re
);

    // 存储器数组
    reg [31:0] mem [0:MEM_DEPTH-1];

    // 将字节地址转换为 word 地址
    wire [$clog2(MEM_DEPTH)-1:0] i_word_addr;
    wire [$clog2(MEM_DEPTH)-1:0] d_word_addr;

    assign i_word_addr = i_addr[$clog2(MEM_DEPTH)+1:2];  // 右移2位，忽略低2位
    assign d_word_addr = d_addr[$clog2(MEM_DEPTH)+1:2];

    // TODO: 实现组合逻辑读
    //   always @(*) begin
    //       i_rdata = mem[i_word_addr];
    //       d_rdata = (d_re) ? mem[d_word_addr] : 32'b0;
    //   end

    // TODO: 实现时序逻辑写
    //   always @(posedge clk) begin
    //       if (d_we) mem[d_word_addr] <= d_wdata;
    //   end

    //--------------------------------------------------------------------------
    // 仿真辅助：初始化存储器
    //--------------------------------------------------------------------------
    // 在仿真开始时加载测试程序
    `ifdef SIMULATION
    initial begin
        // $readmemh("path/to/program.hex", mem);
        // 或手动初始化：
        // mem[0] = 32'h00500113;  // addi x2, x0, 5
        // mem[1] = 32'h00300193;  // addi x3, x0, 3
        // mem[2] = 32'h002081b3;  // add x3, x1, x2
        // ...
    end
    `endif

endmodule
