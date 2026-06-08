# 阶段二：数字逻辑基础

## 1. 为什么需要数字逻辑？

CPU 本质上是一个**数字逻辑电路**。在学习处理器微架构之前，需要理解：
- 组合逻辑：输出仅取决于当前输入（无记忆）
- 时序逻辑：输出取决于当前输入 + 历史状态（有记忆）

## 2. 组合逻辑

### 基本逻辑门

| 门 | 符号 | 表达式 | 真值表（A,B → Y） |
|----|------|--------|-------------------|
| 非门 (NOT) | ¬ | Y = ¬A | 0→1, 1→0 |
| 与门 (AND) | · | Y = A·B | 00→0,01→0,10→0,11→1 |
| 或门 (OR) | + | Y = A+B | 00→0,01→1,10→1,11→1 |
| 异或门 (XOR) | ⊕ | Y = A⊕B | 00→0,01→1,10→1,11→0 |
| 与非门 (NAND) | ↑ | Y = ¬(A·B) | 00→1,01→1,10→1,11→0 |
| 或非门 (NOR) | ↓ | Y = ¬(A+B) | 00→1,01→0,10→0,11→0 |

> NAND 和 NOR 是"通用门"——仅用 NAND 或仅用 NOR 就能实现任何组合逻辑。

### CPU 中常见的组合逻辑组件

#### 多路复用器 (MUX)
```verilog
// 2:1 MUX — 选择两个输入中的一个输出
assign y = sel ? a : b;

// 4:1 MUX
always @(*) begin
    case (sel)
        2'b00: y = a;
        2'b01: y = b;
        2'b10: y = c;
        2'b11: y = d;
    endcase
end
```
在 CPU 中无处不在：ALU 输入选择、寄存器写回数据选择、PC 下一值选择等。

#### 译码器 (Decoder)
```verilog
// 3:8 译码器 — n位输入 → 2^n位输出（one-hot）
always @(*) begin
    y = 8'b0;
    y[sel] = 1'b1;
end
```
在 CPU 中用于：指令译码（opcode → 各指令类别的 one-hot 使能信号）。

#### 加法器 (Adder)
```verilog
// 32位全加器（综合工具会自动优化）
assign sum = a + b;
assign {carry_out, sum} = a + b + carry_in;  // 带进位
```
在 CPU 中用于：ALU、PC+4、分支目标地址计算。

#### 移位器 (Shifter)
```verilog
// 桶形移位器
assign y = a << shamt;   // 逻辑左移
assign y = a >> shamt;   // 逻辑右移
assign y = $signed(a) >>> shamt;  // 算术右移
```

#### ALU — 所有运算的组合
```verilog
// 简化的 ALU
always @(*) begin
    case (alu_control)
        4'b0000: result = a + b;          // ADD
        4'b0001: result = a - b;          // SUB
        4'b0010: result = a & b;          // AND
        4'b0011: result = a | b;          // OR
        4'b0100: result = a ^ b;          // XOR
        4'b0101: result = a << b[4:0];    // SLL
        4'b0110: result = a >> b[4:0];    // SRL
        4'b0111: result = $signed(a) >>> b[4:0]; // SRA
        4'b1000: result = ($signed(a) < $signed(b)) ? 1 : 0; // SLT
        default: result = 32'b0;
    endcase
end
```

## 3. 时序逻辑

### D 触发器 (D Flip-Flop)
```verilog
// 上升沿触发的 D 触发器
always @(posedge clk) begin
    q <= d;  // <= 是非阻塞赋值，用于时序逻辑
end

// 带同步复位的 D 触发器
always @(posedge clk) begin
    if (rst)
        q <= 0;
    else
        q <= d;
end
```

### 寄存器 (Register)
```verilog
// 32位寄存器（带写使能）
always @(posedge clk) begin
    if (rst)
        reg_data <= 32'b0;
    else if (write_en)
        reg_data <= write_data;
end
```

### 寄存器文件 (Register File)
32个寄存器的集合体——CPU 的核心存储结构。
```verilog
// 寄存器文件（简化版）
reg [31:0] rf [31:0];  // 32个32-bit寄存器

always @(posedge clk) begin
    if (we3 && (a3 != 5'b0))  // x0 永远为 0，不可写
        rf[a3] <= wd3;
end

assign rd1 = (a1 == 5'b0) ? 32'b0 : rf[a1];  // 读x0返回0
assign rd2 = (a2 == 5'b0) ? 32'b0 : rf[a2];
```

### 有限状态机 (FSM)
```verilog
// Moore 型状态机
localparam IDLE = 2'b00, FETCH = 2'b01, EXEC = 2'b10, WB = 2'b11;

reg [1:0] state, next_state;

// 状态寄存器
always @(posedge clk) begin
    if (rst)
        state <= IDLE;
    else
        state <= next_state;
end

// 下一状态逻辑（组合）
always @(*) begin
    case (state)
        IDLE:  next_state = FETCH;
        FETCH: next_state = EXEC;
        EXEC:  next_state = WB;
        WB:    next_state = FETCH;
        default: next_state = IDLE;
    endcase
end

// 输出逻辑（组合）
always @(*) begin
    // 根据 state 产生控制信号
end
```

## 4. Verilog 基础速成

### 模块声明
```verilog
module module_name #(
    parameter WIDTH = 32          // 参数（可重写）
) (
    input  wire             clk,    // 时钟
    input  wire             rst_n,  // 复位（低有效）
    input  wire [WIDTH-1:0] data_in,
    output reg  [WIDTH-1:0] data_out
);
    // 模块体
endmodule
```

### 关键语法
```verilog
// 连续赋值（组合逻辑）
assign y = a & b;

// always块（组合逻辑 — 用 = 阻塞赋值）
always @(*) begin
    y = a & b;
end

// always块（时序逻辑 — 用 <= 非阻塞赋值）
always @(posedge clk) begin
    q <= d;
end

// 位拼接
assign {carry, sum} = a + b;          // carry 1bit, sum 32bit
assign sign_ext = {{16{imm[15]}}, imm[15:0]};  // 符号扩展

// 常量
assign x = 32'hDEAD_BEEF;  // 十六进制
assign x = 32'b1010;       // 二进制
assign x = 10'd42;         // 十进制
```

### 阻塞 vs 非阻塞赋值
| | = (阻塞) | <= (非阻塞) |
|---|---------|------------|
| 用于 | 组合逻辑 (always @(*)) | 时序逻辑 (always @(posedge clk)) |
| 行为 | 立即生效，顺序执行 | 所有RHS先求值，再同时更新LHS |
| 理解 | 像软件编程 | 像硬件并行 |

**规则**：
- 组合逻辑：仅用 `=`
- 时序逻辑：仅用 `<=`
- **永远不要在一个 always 块中混用 `=` 和 `<=`**

## 5. 验证与仿真

### Testbench 基本结构
```verilog
`timescale 1ns / 1ps    // 时间单位 / 时间精度

module tb_example;
    // 输入声明为 reg（testbench 驱动）
    reg       clk;
    reg       rst_n;
    reg [3:0] a, b;
    
    // 输出声明为 wire（testbench 观测）
    wire [4:0] sum;
    
    // 实例化 DUT (Device Under Test)
    adder #(.WIDTH(4)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .sum(sum)
    );
    
    // 时钟生成
    initial clk = 0;
    always #5 clk = ~clk;  // 周期 10ns = 100MHz
    
    // 测试向量
    initial begin
        // VCD 波形输出
        $dumpfile("tb_example.vcd");
        $dumpvars(0, tb_example);
        
        // 复位
        rst_n = 0;
        #20 rst_n = 1;
        
        // 测试用例
        a = 3; b = 5;
        #10;
        $display("3 + 5 = %d", sum);  // 打印结果
        
        a = 7; b = 8;
        #10;
        $display("7 + 8 = %d", sum);
        
        $finish;  // 结束仿真
    end
endmodule
```

### 仿真命令（Icarus Verilog）
```bash
# 编译
iverilog -o tb_example.vvp tb_example.v adder.v

# 运行
vvp tb_example.vvp

# 查看波形
gtkwave tb_example.vcd
```

## 6. CPU 设计师需要的思维方式

### 硬件思维 vs 软件思维

| 软件思维 | 硬件思维 |
|----------|----------|
| 顺序执行 | 一切并行执行 |
| 函数调用 | 信号连接（连线） |
| 变量 | 寄存器 + 导线 |
| for 循环 | 展开为并行硬件或状态机 |
| if/else | MUX 或优先级编码器 |
| 内存分配 | 选择器 + 存储单元 |

### 组合逻辑的陷阱
- **不完整敏感列表**：`always @(a)` 遗漏了 `b` → 用 `always @(*)`
- **组合环路**：输出反馈回输入形成环路 → 震荡
- **信号竞争**：同一信号在多处驱动 → 用 `assign` 或 `always @(*)`，别混用

### 时序逻辑的陷阱
- **亚稳态**：异步输入违反 setup/hold 时间 → 用同步器（两级 FF）
- **时钟域跨越**：不同时钟域信号直接通信 → 用 FIFO 或握手协议
- **阻塞赋值用于时序**：导致仿真与实际硬件行为不一致

## 7. 下一步

掌握了组合逻辑和时序逻辑的建模方法后，进入 [阶段三：CPU 微架构](03-microarchitecture.md)，将这些组件拼成一台完整的处理器。
