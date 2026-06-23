# 编码规范

> 本文档定义Verilog编码规范。

---

## 1. 基本规则

### 1.1 核心原则

【原则】**简单、规范、可读、可维护** - 对应可靠性、一致性、可读性、可维护性

### 1.2 文件规则

| 规则 | 描述 |
|------|------|
| 【规则】一个verilog文件只包含一个模块 | - |
| 【规则】文件名与模块名一致 | - |
| 【规则】顶层模块禁止使用组合逻辑运算 | - |
| 【规则】除特殊情况外，IP设计禁止使用`define | define定义应放在单独文件(.vh)中 |
| 【规则】使用`define时加块名前缀 | 确保宏定义唯一性 |

### 1.3 语法规则

| 规则 | 描述 |
|------|------|
| 【规则】一行一个声明/表达式 | - |
| 【规则】用括号明确运算符优先级 | 不依赖默认优先级 |
| 【规则】禁止使用`timescale | 仅在tb_top中使用 |
| 【规则】禁止信号赋值为x/z | - |
| 【规则】禁止直接使用原语 | - |
| 【规则】敏感列表只包含时钟和复位 | - |
| 【规则】除特殊情况外禁止latch | - |
| 【规则】RTL中禁止使用/或% | - |
| 【规则】RTL中禁止使用forever/repeat/while | - |
| 【规则】可综合代码中禁止使用$函数 | 包括$clog2 |
| 【规则】时序逻辑用'<='，组合逻辑用'=' | - |
| 【规则】禁止reg a = x初始化 | 用异步复位赋初值 |
| 【规则】每个块、if/else分支必须有begin/end | - |
| 【规则】else和default**必须显式写出** | **else分支必须显式写出，不能省略** |
| 【规则】除IP顶层外使用参数化位宽 | - |
| 【规则】运算中位宽一致 | - |
| 【规则】位宽大端，数组小端 | LSB必须为0 |
| 【规则】赋值中位宽显式 | 用{{(WIDTH-5){1'b0}},5'd10}风格 |
| 【规则】禁止组合逻辑环路 | 避免DC工具随机性 |
| 【规则】禁止同一信号多驱动 | - |
| 【规则】除指定总线信号外，使能高有效 | - |
| 【规则】禁止多周期路径 | - |
| 【规则】除PAD外禁止inout信号 | - |

---

## 2. 代码结构

### 2.1 代码框架

```text
模块
├── 文件头
├── 模块声明（一段式）
├── 代码体
│   ├── 代码头（参数）
│   ├── 代码段（按数据流/控制流排列）
│   │   ├── 一级代码段（顶层数据流）
│   │   ├── 二级代码段（子功能）
│   │   └── 三级代码段（基础组件）
│   └── 代码尾（DFX等）
└── Endmodule
```

### 2.2 代码段落结构

【标准】每个段落包含三部分（全部可选）：
1. **段落注释**
2. **声明**
3. **实现**

### 2.3 具体规则

| 规则 | 描述 |
|------|------|
| 【规则】所有verilog文件必须有文件头 | 至少包含作者、模块名、功能描述、版本 |
| 【规则】模块端口使用**一段式**声明 | - |
| 【规则】localparam和genvar放在代码头 | genvar: i, j, k, m, n对应1-5级 |
| 【规则】每个代码块只声明 | ①本代码块输出信号（从来源角度命名），②下级反馈输入信号（从用途角度命名，加gen_later注释） |
| 【指导】代码块按数据流/控制流排列 | 分为一级、二级、三级块 |
| 【指导】用assign连接前级输出到后级输入 | - |

---
## 3. 缩进规则

### 3.1 核心规则

【规则】**同级信号同缩进，第i级信号缩进(i-1)*2空格，禁止用tab**

【规则】**begin必须另起一行，与end对齐**

【注意】第一级代码必须从第1列开始，begin/generate/case本身不缩进，但换行后级别增加，加2空格缩进

### 3.2 正确示例（2空格）

```verilog
// 正确缩进示例：
always @(posedge pde_clk or negedge pde_rst_n)
begin
  if (!pde_rst_n)
  begin
    sig_a <= 1'b0;
    sig_b <= 1'b0;
  end
  else if (condition)
  begin
    sig_a <= 1'b1;
    sig_b <= 1'b1;
  end
  else
  begin
    sig_a <= sig_c;
    sig_b <= sig_d;
  end
end
```

### 3.3 错误示例

```verilog
// 错误：4空格缩进
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sig <= 1'b0;
    end
end

// 错误：begin与always同行
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    sig <= 1'b0;
  end
end
```

---

## 4. 例化规则

### 4.1 例化要素

【规则】**例化必须包含IO属性和位宽信息**

【示例】从模块顶层声明复制接口信号，调整IO属性、位宽和注释为例化格式

```verilog
// 示例格式：
module_name
#(
  .PARAM1 (VALUE1)
)
u_instance_name
(
  // input/output, width, description
  .signal_name   ( connected_signal  )  // I/O, [WIDTH-1:0], description
);
```

### 4.2 位宽匹配

| 规则 | 描述 |
|------|------|
| 【规则】除一级IP互连外，信号位宽必须匹配 | 不匹配时在模块内处理 |
| 【规则】例化接口位宽与模块内部一致 | - |
| 【指导】参数连接端口时定义与端口同位宽 | 避免位宽不匹配 |

---
## 5. 注释规则

### 5.1 核心原则

【原则】用充分注释提高代码可读性和可维护性

【原则】**避免无意义注释**（重复信号名）

【指导】有意义注释类型：
1. 功能注释（段落注释）
2. TODO/FIXME项
3. 内容细节（模式描述、数据类型）
4. 协议描述（连接、时序、约束）

### 5.2 注释格式规则

| 规则 | 描述 |
|------|------|
| 【规则】注释只用'//' | **禁止用'/**/'** |
| 【规则】**注释用英文** | - |
| 【规则】总线信号需要段落注释 | 非总线信号必须有额外注释 |
| 【指导】保持注释简短 | 平均每段代码一句话 |

### 5.3 段落注释格式

【指导】级别0：// + 80个横线，级别1：// + 40个横线，以此类推

```verilog
//================================================================================
// 级别0段落注释
//================================================================================

//--------------------------------------------------------------------------------
// 级别1段落注释
//--------------------------------------------------------------------------------

//----------------------------------------
// 级别2段落注释
//----------------------------------------

//--------------------
// 级别3段落注释
//--------------------

//----------
// 级别4段落注释
//----------

// 级别5注释
```

### 5.4 注释关键字

【规则】使用FIXME、TODO关键字（GVIM会高亮）

| 关键字 | 含义 | 使用 |
|--------|------|------|
| FIXME risk | 不确定风险 | 需仿真观察和多场景测试 |
| FIXME timing | 时序问题 | DC或PR时关注 |
| FIXME neg | 可能为负 | 需功能覆盖 |
| FIXME overflow | 余量可能不足 | 可能溢出，需关注 |
| FIXME except | 特殊情况操作 | 需关注 |
| TODO tmp | 未完成 | 下版本完成 |
| TODO opt | 可优化 | 资源/功耗优化 |
| TODO param | 参数问题 | 参数未自适应 |
| TODO note | 缺少注释 | 需补充 |
| TODO width | 位宽不匹配 | - |

### 5.5 ECO注释格式

【规则】ECO：禁止删除/修改原代码，注释掉原代码，后面加新代码

新代码格式：
```verilog
//ecopoint start , operation/purpose,@date@modifier
new_code
//ecopoint end
```

修改格式：
```verilog
//ecopoint start , operation/purpose,@date@modifier
// old_code
new_code
//ecopoint end
```

删除格式：
```verilog
//ecopoint start , operation/purpose,@date@modifier
// old_code
//ecopoint end
```

---
## 6. 对齐规则

### 6.1 代码风格

【指导】使用宽松代码风格，但为代码隔离（非对齐）只用1空格或空行，避免过度宽松

【示例】parameter、localparam、wire、//、assign直接跟信号，用一个空格

### 6.2 对齐规则

【指导】**同类多行代码需要对齐**

【示例】基于=、()、[]、-1:0、,、//对齐

```verilog
// 正确示例：
wire [WIDTH-1:0]  sig_a;      // sig_a注释
wire [WIDTH-1:0]  sig_b;      // sig_b注释
wire              sig_c;      // sig_c注释

assign sig_a = (condition) ? value1 : value2;  // 注释
assign sig_b = (condition) ? value3 : value4;  // 注释
assign sig_c = sig_a & sig_b;                  // 注释
```

### 6.3 行长度

| 指导 | 描述 |
|------|------|
| 【指导】一般功能代码：每行最多80字符 | - |
| 【指导】例化、generate可超过80字符 | 用assign、function、缩写减少 |
| 【指导】功能模块每文件最多2000行 | - |

---

## 7. 时钟复位规则

### 7.1 时钟规则

| 规则 | 描述 |
|------|------|
| 【规则】时钟/复位处理放在专用模块 | - |
| 【规则】时钟信号用_clk后缀 | - |
| 【规则】同级IP使用相同时钟命名 | - |
| 【规则】禁止用assign重命名时钟信号 | - |
| 【规则】禁止模块内时钟分频/倍频/移相 | 仅在专用时钟模块中 |
| 【规则】使用上升沿触发 | 除协议要求外禁止双边沿 |
| 【规则】移相时钟需加后缀 | 如a_clk_p180 |

### 7.2 复位规则

| 规则 | 描述 |
|------|------|
| 【规则】异步复位：rst后缀，同步复位：srst后缀 | 低有效加_n |
| 【规则】所有复位都是异步 | 异步置位、同步释放 |
| 【规则】所有异步复位都是低有效 | - |
| 【规则】复位信号不能内部产生 | - |
| 【规则】禁止异步复位+置位同时用 | 置位指从上级模块来的值 |
| 【规则】异步复位和同步置位分两句写 | - |

### 7.3 CDC规则

| 规则 | 描述 |
|------|------|
| 【规则】单bit CDC：用2级同步 | 加_sync后缀 |
| 【规则】单脉冲：在源端延时足够，或做扩展后跨 | 跨后取上升沿 |
| 【规则】除时钟模块外禁止时钟参与运算 | - |
| 【指导】一个模块一个时钟 | CDC在专用模块中 |
| 【指导】一个模块一个时钟/复位 | 时钟切换在专用模块中 |
| 【指导】大位宽CDC用FIFO | - |
| 【指导】用CBB模块做CDC | - |

---

## 8. 状态机规则

### 8.1 使用限制

【原则】**控制逻辑不要用状态机实现，用任务分解CBB**

【例外】**只有应对随机握手任务时，可以用只有IDLE/WAIT/WORK三个状态的状态机**

### 8.2 状态机规则（如必须使用）

| 规则 | 描述 |
|------|------|
| 【指导】避免casex/casez | 显式列出所有状态 |
| 【指导】组合逻辑和时序逻辑分开放always块 | - |

---
## 9. 代码模板

### 9.1 文件头模板

```verilog
//////////////////////////////////////////////////////////////
//Company       : hikvision
//Engineer      : name
//Created Time  : YYYY/MM/DD HH:MM
//File Name     : module_name.v
//Project Name  :
//Target Devices:
//Tool Versions :
//Description   :
//               brief description
//Dependencies  :
//Revision      : V0.1, Initial Version
//Additional Comments
///////////////////////////////////////////////////////////
```

### 9.2 模块声明模板

```verilog
module module_name
#(
  parameter PARAM1        = 32  ,
  parameter PARAM2        = 4     //
)
(
  input                                 clk             ,
  input                                 rst_n           ,

//----------------------------------------
// CTRL_BUS IN
//----------------------------------------
  input                                 sof_in          ,
  output wire                           eof_out         ,
  input       [DATA_WIDTH    -1:0]      data_in         ,

//----------------------------------------
// CTRL_BUS OUT
//----------------------------------------
  output wire                           sof_out         ,
  input                                 eof_in          ,
  output wire [DATA_WIDTH    -1:0]      data_out        , // HOLD AFTER SOF

//----------------------------------------
// DFX
//----------------------------------------
  output wire [EWIDTH        -1:0]      event_out       ,
  output wire [SWIDTH        -1:0]      status_out      ,
  output wire [MWIDTH        -1:0]      monitor_out
);
```
### 9.3 代码体模板

```verilog
//----------------------------------------
// Code Header
//----------------------------------------
localparam CNT_WIDTH       = 8   ;

//----------------------------------------
// Section Comment
//----------------------------------------
// Sub-section comment
//----------------------------------------
wire working_sig ;
wire event_sig   ; // event indicator

assign sof_out = sof_in && (~working_sig) ;
assign event_sig = sof_in && (working_sig) ;

hik_working
#(
  .PRIORITY_TYPE ("PULL_DOWN")  // "PULL_DOWN" OR "PULL_UP"
)
u_working_inst
(
  .clk           ( clk           ) , // input
  .rst_n         ( rst_n         ) , // input
  .sof           ( sof_out       ) , // input
  .eof           ( eof_in        ) , // input
  .working       ( working_sig   )   // output
);

//----------------------------------------
// Sequential Logic
//----------------------------------------
always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
  begin
    data_out <= {DATA_WIDTH{1'b0}};
  end
  else if (sof_out)
  begin
    data_out <= data_in;
  end
  else
  begin
    data_out <= data_out;
  end
end
```

### 9.4 Always块模板

```verilog
always @(posedge clk or negedge rst_n)
begin
  if (!rst_n)
  begin
    sig_a <= {WIDTH{1'b0}};
    sig_b <= {WIDTH{1'b0}};
  end
  else if (condition1)
  begin
    sig_a <= value1;
    sig_b <= value2;
  end
  else if (condition2)
  begin
    sig_a <= value3;
    sig_b <= value4;
  end
  else
  begin
    sig_a <= sig_a;
    sig_b <= sig_b;
  end
end
```
### 9.5 Case语句模板

```verilog
always @(*)
begin
  case (case_signal)
    VALUE1 :
    begin
      out1 = val1;
      out2 = val2;
    end
    VALUE2 :
    begin
      out1 = val3;
      out2 = val4;
    end
    default :
    begin
      out1 = default_val1;
      out2 = default_val2;
    end
  endcase
end
```

### 9.6 For循环模板

```verilog
// 单层
generate
  for (i=0; i<WIDTH; i=i+1)
  begin : gen_block_name
    // logic here
    assign out[i] = in[i] & enable;
  end
endgenerate

// 双层
generate
  for (i=0; i<ROWS; i=i+1)
  begin : gen_row
    for (j=0; j<COLS; j=j+1)
    begin : gen_col
      // logic here
      assign out[i][j] = in[i][j] & enable;
    end
  end
endgenerate
```

### 9.7 CBB例化模板

```verilog
hik_cnt_timeopt
#(
  .NUM_WIDTH    ( 8             ) , // = 8
  .SUPPORT_TYPE ( "SUPPORT_1"   )   // "SUPPORT_1" or "BIG_NUM"
)
u_cnt_inst
(
  .clk           ( clk           ) , // input
  .rst_n         ( rst_n         ) , // input
  .srst          ( 1'b0          ) , // input
  .xx_en         ( seq_en        ) , // input
  .xx_num        ( dat_num       ) , // input [NUM_WIDTH-1:0]
  .xx_cnt        ( seq_cnt       ) , // output [NUM_WIDTH-1:0]
  .xx_cnt_lst    ( seq_cnt_lst   ) , // output
  .xx_en_lst     ( seq_en_lst    )   // output
);
```
### 9.8 总线声明模板

#### BUF总线

```verilog
// Declaration
wire                                buf_wr_en   ;
wire [BUF_AWIDTH        -1:0]       buf_wr_addr ;
wire [BUF_DWIDTH        -1:0]       buf_wr_dat  ;
wire                                buf_rd_en   ;
wire [BUF_AWIDTH        -1:0]       buf_rd_addr ;
wire [BUF_DWIDTH        -1:0]       buf_rd_dat  ;
wire                                buf_rd_vld  ;

// Single port mem
wire [BUF_AWIDTH        -1:0]       mem_adr; // memory read/write address
wire [BUF_DWIDTH        -1:0]       mem_wdt; // memory data in
wire                                mem_ceb; // chip enable
wire                                mem_web; // memory write enable
wire [BUF_DWIDTH        -1:0]       mem_rdt; // memory data out
wire                                mem_ls ; // light sleep mode
```

#### FIFO总线

```verilog
// Declaration
wire                     fifo_wr_en     ;
wire [FIFO_DWIDTH  -1:0] fifo_wr_dat    ;
wire [FIFO_NWIDTH  -1:0] fifo_wr_avcnt  ;
wire                     fifo_wr_full   ;
wire                     fifo_rd_en     ;
wire [FIFO_DWIDTH  -1:0] fifo_rd_dat    ;
wire [FIFO_NWIDTH  -1:0] fifo_rd_avcnt  ;
wire                     fifo_rd_empty  ;
```

---

## 10. 代码检查清单

- [ ] 一行一个声明/表达式？
- [ ] 用括号明确运算符优先级？
- [ ] 时序'<='，组合'='？
- [ ] 每个if/else有begin/end？
- [ ] **else分支显式写出（未省略）？**
- [ ] 参数化位宽声明？
- [ ] 运算中位宽一致？
- [ ] 注释只用'//'（不用'/**/'）？
- [ ] **注释用英文？**
- [ ] **注释简短（每段一句话）？**
- [ ] **2空格缩进（不是4）？**
- [ ] **begin另起一行，与end对齐？**
- [ ] 同类代码对齐（=、()、[]等）？
- [ ] 每行最多80字符（例化除外）？
- [ ] 每文件最多2000行？
- [ ] 时钟信号用_clk后缀？
- [ ] 复位信号用rst_n/srst后缀？
- [ ] **控制逻辑用任务分解CBB（不用状态机）？**

