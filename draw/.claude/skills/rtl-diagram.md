---
name: rtl-diagram
description: 分析 RTL (Verilog/SystemVerilog) 代码并生成 drawio 格式的模块框图、数据流图、控制流图和时钟复位图。支持 NPU、RISC-V 处理器、SoC 及通用数字 IC 设计代码。
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# RTL 代码框图生成器

分析 Verilog/SystemVerilog RTL 源代码，提取架构信息，生成 4 种 `.drawio` 格式的框图文件：

1. **模块框图** — 模块层次结构、端口接口和模块间互连
2. **数据流图** — 数据流向、流水线级数、存储单元、数据位宽标注
3. **控制流图** — 有限状态机（FSM）、控制信号生成、握手协议
4. **时钟/复位图** — 时钟域划分、PLL/时钟门控、复位树、跨时钟域（CDC）路径

## 使用方法

调用时指定 RTL 源码路径：

```
/rtl-diagram <RTL源码目录路径>
```

或者指定顶层模块及文件列表：

```
/rtl-diagram --top npu_top --files example/*.sv
```

可选参数：
- `--top <模块名>` — 指定顶层模块名称
- `--files <glob>` — RTL 源文件的 glob 匹配模式
- `--output <目录>` — .drawio 文件的输出目录（默认：`output/`）
- `--types <列表>` — 逗号分隔的框图类型：block,dataflow,control,clock（默认：全部）

---

## 工作流程：从零到生成框图

### 第0步：快速侦察

面对一个新的 RTL 代码库，按以下顺序快速了解设计：

1. **找到顶层文件**：搜索 `*top*.sv`、`*chip*.sv`、`*soc*.sv`、`*core*.sv`
2. **阅读顶层模块**：提取子模块实例化列表和主要端口
3. **识别关键子模块**：优先读取 CPU 核、NPU 阵列、DMA、SRAM 等核心模块
4. **识别总线架构**：搜索 AXI、TileLink、ICB、Wishbone 等总线协议信号
5. **识别时钟架构**：读取 `*clk*.sv`、`*rst*.sv`、PLL/MMCM 实例

### 第0.5步：判断设计类型

根据顶层结构判断设计类型，这会影响后续框图的组织方式：

| 设计类型 | 典型特征 | 框图组织方式 |
|---------|---------|------------|
| **SoC 集成型** | FPGA 顶层 + PLL + MIG + SoC 子系统 + 外设 | 按物理层次：FPGA 原语 → SoC → 子系统 → 核 |
| **CPU 核型** | 取指 + 执行 + 访存 + 总线，多级时钟门控 | 按流水线：IFU → EXU → LSU → BIU |
| **NPU 加速器型** | MAC 阵列 + SRAM + DMA + 控制器 + 量化 | 按数据流：DRAM → DMA → SRAM → MAC → Act → Pool → Quant |
| **外设子系统型** | 总线矩阵 + 多个外设 + 适配器/桥接 | 按总线拓扑：主机 → 交叉开关 → 各外设 |

---

## 阶段一：RTL 解析（增强版）

### 1.1 模块声明

对每个 `module ... endmodule` 块，提取：
- **模块名** — `module` 关键字后的标识符
- **参数** — `#(parameter WIDTH=8, ...)` 参数列表
- **端口** — 每个端口的方向、数据类型、位宽和名称

识别模式：
```
module <模块名> #(<参数>) (<端口>);
module <模块名> (<端口>);
```

端口模式：
```
input  wire [WIDTH-1:0] data_in,
output logic [7:0]      data_out,
input  wire             clk,
output reg              valid
```

解析位宽：`[MSB:LSB]`，无范围指定则为单比特。

### 1.2 自动生成代码的识别（Chisel/SpinalHDL/Verilator）

**关键特征：**
- 极长的扁平化端口名（如 `io_external_devices_ports_0_a_valid`）
- 带有 `_bits_` 子字段的结构体端口展开
- 参数化类型 `type RegDataT=logic [31:0]`
- 大量 `import` 包引用

**处理策略：**
1. 忽略 `_bits_` 中间的层级，将其归类为总线信号组
2. 将 `io_` 前缀的端口归类为外部接口
3. 自动生成代码内部例化的模块可能有前缀（如 `u_`、`i_`）
4. 关注模块间连线的信号名模式来推断连接关系

### 1.3 内部信号

提取：
- **Wire/reg/logic 声明** — 信号名、位宽、类型
- **Localparam / parameter** — 用于状态编码或配置的常量
- **typedef / enum** — 尤其关注状态枚举定义
- **结构体/接口类型** — `tl_h2d_t`（TileLink）、`ICB` 总线结构体

### 1.4 子模块实例化

**标准模式：**
```
模块名 #(.参数(值)) 实例名 (.端口(信号), ...);
```

**特殊模式：**
- **Chisel 生成的黑盒**：`CoralNPUChiselSubsystem i_chisel_subsystem (...)` — 端口可能有数百行
- **FPGA IP 核**：`ddr_system_bd_ddr4_0_0 i_ddr4 (...)` — Xilinx MIG/MMCM 等
- **原语实例化**：`STARTUPE3 i_startupe3 (...)`、`BUFG u_bufg (...)`
- **适配器/桥接器**：`tlul_adapter_sram #(...) i_rom_adapter (...)` — 连接不同总线协议
- **仲裁控制器**：`e203_itcm_ctrl u_e203_itcm_ctrl (...)` — 多主访问仲裁

### 1.5 总线架构识别（新增）

识别以下总线协议并标注在框图中：

| 总线协议 | 识别特征 | 标注颜色 |
|---------|---------|---------|
| **AXI4** | `*_awvalid/*_awready`、`*_wvalid`、`*_bvalid`、`*_arvalid`、`*_rvalid` | #0066CC 蓝色 |
| **TileLink** | `tl_*_o`/`tl_*_i`、`a_valid`、`d_valid`、`a_opcode`、`a_address` | #0066CC 蓝色 |
| **ICB (自定义)** | `*_icb_cmd_valid`、`*_icb_rsp_valid` | #0066CC 蓝色 |
| **Wishbone** | `wb_*`、`*_stb`、`*_ack`、`*_cyc` | #0066CC 蓝色 |

识别总线拓扑：
- **交叉开关/矩阵**：一个模块连接 N 个主设备到 M 个从设备
- **适配器/桥接**：两个不同协议之间的转换模块
- **仲裁器**：多主设备共享单一从设备的控制器

### 1.6 always 块与 assign 语句

- **always_ff @(posedge clk ...)** — 时序逻辑，同时识别所属时钟域
- **always_comb** — 组合逻辑
- **always @(*)** — 组合逻辑（旧式写法）
- **assign** — 连续赋值语句，数据通路连接

**新增：时钟门控使能识别**
```systemverilog
// BUFGCE 模式 (Xilinx FPGA)
BUFGCE u_core_clk_gate (.I(clk), .CE(clk_en), .O(gated_clk));
// 手动门控模式
assign gated_clk = clk && clk_en;
// 锁存门控（下降沿锁存使能）
always_ff @(negedge clk or negedge rst_n) clk_en_sync <= clk_en;
```

### 1.7 控制流

识别：
- **FSM 状态** — `parameter`/`localparam` 以 STATE/ST 命名，或 `typedef enum`
- **状态转移** — `always_ff` 内部的 `case(state)` 语句块
- **握手协议** — `valid`/`ready` 对（如 AXI、TileLink）、`req`/`gnt`、`start`/`done`
- **反压机制** — `stall`、`hold`、背压容量信号（如 `queue_capacity`、`remaining_count`）
- **流水线冲刷** — `pipe_flush_req`/`pipe_flush_ack`
- **计数/定时逻辑** — 延迟计数器、超时计数器

### 1.8 时钟与复位

识别：
- **时钟输入** — 名为 `clk`、`clock`、`clk_i`、`*_clk` 的端口
- **时钟生成** — PLL/MMCM 实例、时钟分频器、BUFG/BUFGCE
- **复位输入** — `rst_n`、`rst_ni`（低有效）、`rst`（高有效）
- **多级复位** — `rst_aon`（常开域）、`rst_core`（核心域）、`rst_itcm`（TCM域）
- **复位同步器** — 标准 2-FF 同步器，异步置位/同步释放
- **电源管理信号** — `tcm_sd`（关断）、`tcm_ds`（深睡）、`tcm_ls`（浅睡）
- **时钟门控控制** — `core_cgstop`、`tcm_cgstop`、`core_clk_en`

---

## 阶段二：框图生成

### Drawio XML 结构（必须严格遵守）

每个 .drawio 文件必须严格遵循以下结构：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="app.diagrams.net" modified="2026-06-08T00:00:00.000Z" agent="Claude Code RTL Diagram Generator" version="24.0.0">
  <diagram name="框图标题" id="diagram-1">
    <mxGraphModel dx="0" dy="0" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="0" pageScale="1" pageWidth="1400" pageHeight="1000" math="0" shadow="0">
      <root>
        <mxCell id="0"/>
        <mxCell id="1" parent="0"/>
        <!-- 所有框图元素放在此处，作为 id="1" 的子元素 -->
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

**关键规则：**
1. id="0" 和 id="1" 必须始终作为前两个元素存在
2. 所有顶点和边的 `parent` 必须为 `"1"`
3. 每个 mxCell 必须使用唯一的整数 id
4. 每条边内部必须包含 `<mxGeometry relative="1" as="geometry"/>`
5. 输出文件中禁止出现 `<!-- -->` 形式的 XML 注释
6. 转义特殊字符：`&` → `&amp;`，`<` → `&lt;`，`>` → `&gt;`，`"` → `&quot;`
7. 先生成所有顶点，再生成所有边
8. 顶点 id 编号从 2 开始
9. 中文标题中的 `&` 也需要转义为 `&amp;`（如 `时钟 &amp; 复位`）

---

## 框图类型一：模块框图

### 布局算法（增强版）

**多层次树状布局：**

1. **顶层模块**置于画布顶部居中（x=500, y=100 左右），深色背景
2. **按功能/时钟域分组**子模块，每组横向排列：
   - **基础设施层**（y=240）：PLL、时钟生成、复位控制、FPGA 原语
   - **SoC/集成层**（y=420）：顶层 SoC 子系统、总线矩阵
   - **核心计算层**（y=600）：CPU 核、NPU 阵列、向量处理器
   - **存储层次层**（y=750）：SRAM、TCM、ROM、Cache
   - **外设/IO 层**（y=900）：UART、SPI、GPIO、调试模块
3. **嵌套展开**：对于重要的子模块（如 CPU 核），在右侧或下方展开内部子模块
4. 使用**虚线分组框**包裹同层模块，标注层名称
5. **模块框大小**：最小 140×60，最大 300×100，由端口数和标签长度决定

### 实际案例：Coral NPU 模块框图结构

```
chip_nexus (FPGA 顶层)
├── [基础设施层]
│   ├── i_clkgen (clkgen_wrapper / PLL)
│   ├── i_startupe3 (STARTUPE3 FPGA 原语)
│   └── i_ddr4 (DDR4 MIG IP)
└── [SoC 子系统层]
    └── i_coralnpu_soc (coralnpu_soc)
        ├── i_chisel_subsystem (CoralNPUChiselSubsystem)
        │   ├── RISC-V 标量核
        │   ├── RvvCore (向量核) ← 展开内部
        │   │   ├── RvvFrontEnd
        │   │   └── rvv_backend
        │   └── TileLink 总线矩阵
        ├── i_uart0, i_uart1
        ├── i_rom + i_rom_adapter
        └── i_sram + i_sram_adapter
```

### 实际案例：蜂鸟 E203 模块框图结构

```
e203_cpu_top (CPU 顶层)
├── [时钟/复位/中断 (clk_aon 域)]
│   ├── u_e203_reset_ctrl (复位控制器)
│   ├── u_e203_clk_ctrl (时钟控制器 + 门控)
│   └── u_e203_irq_sync (中断同步器)
├── [核心流水线 (clk_core_* 域)]
│   └── u_e203_core
│       ├── u_e203_ifu (取指单元)
│       ├── u_e203_exu (执行单元)
│       ├── u_e203_lsu (访存单元)
│       └── u_e203_biu (总线接口单元)
├── [TCM 控制器]
│   ├── u_e203_itcm_ctrl (ITCM 控制器)
│   └── u_e203_dtcm_ctrl (DTCM 控制器)
└── u_e203_srams (ITCM/DTCM SRAM)
```

### 顶点模板（保持不变，略）
（沿用此前定义的模板，见下方快速参考颜色表）

### 连线模板（增强版）

**总线矩阵连接（一对多/多对一）：**
使用正交连线 + 中间路径点，从总线模块引出一根主干线，再分叉到各从设备。标注协议名称和数据宽度。

**适配器/桥接器连接：**
适配器模块两侧标注不同的总线协议名称。

---

## 框图类型二：数据流图

### 布局算法（增强版）

**流水线 + 存储层次混合布局：**

1. **数据流向统一从左到右**
2. 数据路径上的**处理单元**形成水平流水线
3. **存储单元**放置在处理单元上方或下方，用纵向连线连接
4. **总线/交叉开关**作为中央枢纽，数据从多个源汇入再分发
5. 在每个连线上标注**数据位宽**和**协议类型**
6. 标注**关键数据变换**（如 INT32→INT16 截断、量化缩放）

### 实际案例：Coral NPU 数据流

```
DDR4 → [AXI4 256b] → TileLink 总线 → SRAM(1M×32b)
                                         ↓
Boot ROM(2K×32b) → TileLink → RvvCore:
  RvvFrontEnd(指令译码) → rvv_backend(ALU lanes) → LSU → 写回 vregfile
                                          ↓
                              UART0/UART1/SPI (IO 输出)
```

### 实际案例：蜂鸟 E203 数据流

```
ITCM(指令) → e203_ifu(取指) → [ir+pc] → e203_exu(译码→regfile→ALU→写回)
                                              ↓
                              e203_lsu(AGU→访存) → DTCM(数据)
                                              ↓
                              e203_biu(ICB 矩阵) → PPI/PLIC/CLINT/FIO/MEM
```

---

## 框图类型三：控制流图

### 布局算法（增强版）

**多状态机并行展示：**

真实设计中通常存在多个并行的状态机，应按功能分组展示：

1. **主控 FSM**（如 NPU 推理流程控制、CPU 流水线控制）
2. **子模块 FSM**（如 MAC 阵列控制、DMA 状态机）
3. **握手协议**（如 valid/ready、AXI 通道握手）
4. **异常/调试流程**（如中断处理、调试模式、错误恢复）
5. 使用表格式的 **Moore 输出表** 汇总各状态的控制信号

### 实际案例：Coral NPU 控制流

- **RvvCore 前端**：IDLE → 等待指令 → 译码/分发（valid/ready 握手，queue_capacity 反压）
- **后端流水线**：DECODE → DISPATCH → EXECUTE（addsub/mask/shift 4路并行）→ WRITEBACK
- **LSU 握手**：LSU 请求 → 等待 ready → LSU 完成写回
- **DDR4 校准**：上电复位 → 等待 PLL locked & EOS → 校准 → 完成
- **TileLink 总线**：A-Channel 请求 → 等待 → D-Channel 响应

### 实际案例：蜂鸟 E203 控制流

- **复位序列**：上电复位（异步）→ 2-FF 同步释放（clk_aon）→ rst_aon 释放 → rst_core 释放
- **时钟门控**：全速运行 → WFI 休眠 → 时钟关闭（core_cgstop）→ [中断] → 恢复
- **IFU→EXU 握手**：IFU 取指 → 等待 EXU ready → EXU 译码 / stall（多周期/RAW/分支）→ 冲刷（pipe_flush）
- **中断处理**：等待中断 → 2-FF 同步 → mtvec 跳转 → ISR → mret
- **调试模式**：正常运行 → [halt] → 暂停 → [step] → 单步 / [ebreak] → 断点 / [resume] → 恢复

---

## 框图类型四：时钟/复位图

### 布局算法（增强版）

**域 + 门控层次布局：**

1. **时钟源**在最左列或顶部
2. PLL/MMCM 在第二列
3. 每个**时钟域**作为独立的虚线区域向右展开
4. 时钟域按**频率和用途**排序：常开域（aon）→ 主系统域 → 核心域 → 外设域 → TCM 域
5. **时钟门控单元**（CG/BUFGCE）标注在域入口处
6. **复位同步器**（RST SYNC）标注在各域顶部
7. **复位分发**用橙色虚线箭头从复位控制器指向各域
8. **CDC 跨域标记**标注在域边界处
9. **电源管理**信号用独立标记标注（sd/ds/ls）

### 实际案例：Coral NPU 时钟域

```
外部晶振(差分) → clkgen_wrapper(PLL) ─┬→ clk_main (80MHz) → coralnpu_soc + TileLink 外设
                                       ├→ clk_48MHz → SPI / 低速外设
                                       ├→ clk_aon → 常开域（永不关闭）
                                       └→ ddr_ui_clk → DDR4 MIG IP (独立域)
                  STARTUPE3 ─→ EOS ─→ mig_sys_rst = ~locked | ~eos | ~rst_ni
```

### 实际案例：蜂鸟 E203 时钟域

```
clk → e203_clk_ctrl ─┬→ clk_aon (常开) → reset_ctrl / clk_ctrl / irq_sync
                      ├→ clk_core_ifu (CG门控) → e203_ifu
                      ├→ clk_core_exu (CG门控) → e203_exu + CSR
                      ├→ clk_core_lsu (CG门控) → e203_lsu
                      ├→ clk_core_biu (CG门控) → e203_biu
                      ├→ clk_itcm (CG + 电源管理) → ITCM SRAM
                      └→ clk_dtcm (CG + 电源管理) → DTCM SRAM
                      WFI → core_cgstop=1 → 关闭 core 时钟 → 中断到达 → 恢复
                      电源管理: tcm_sd(关断) / tcm_ds(深睡) / tcm_ls(浅睡)
```

---

## 阶段三：实际作图经验总结

### 经验 1：按设计类型选择合适的组织方式

| 设计 | 父模块数 | 最大嵌套深度 | 推荐布局宽度 | 推荐策略 |
|------|---------|-------------|-------------|---------|
| 简单 IP | 3-5 | 2 | 800px | 横向展开即可 |
| 中型 SoC | 8-15 | 3 | 1200px | 按功能层分组 |
| 大型 NPU/CPU | 15-30 | 4-5 | 1600px+ | 选重点展开，其余折叠 |

### 经验 2：哪些模块该折叠，哪些该展开

**必须展开的模块**（用户最关心）：
- CPU 核内部的流水线（IFU/EXU/LSU/BIU）
- NPU 阵列的 PE 结构
- 关键数据通路

**可以折叠的模块**（除非用户专门要求）：
- 标准总线适配器/桥接器
- FPGA 原语（BUFG、STARTUPE3）— 除非画时钟复位图
- 简单的寄存器切片/同步器

### 经验 3：连线过多时的简化策略

1. **总线归组**：同一总线的多根信号合并为一根粗线，标注协议名+位宽
2. **省略 reply 通道**：只画 request 方向，ack 方向省略或用小标签
3. **控制信号精简**：只标注关键控制信号（start/done/valid），省略状态回读信号
4. **使用图例**：重复的信号类型用图例说明，不在每条连线上标注

### 经验 4：中文内容的处理

- 所有标题、标签使用中文
- 技术术语（AXI、FSM、CDC）保留英文缩写
- 模块名和实例名保留原 RTL 中的英文名称
- `&` 符号在 XML 中必须写为 `&amp;`，尤其在 "时钟 &amp; 复位" 这类标题中

---

## 快速参考：样式颜色

| 分类 | fillColor | strokeColor | 用途 |
|------|-----------|-------------|------|
| 主要模块 | #dae8fc | #6c8ebf | 数据通路上的主要计算模块 |
| 顶层/层次 | #1a1a2e | #16213e | 顶层模块（深色背景+白字） |
| 存储器 | #fff2cc | #d6b656 | SRAM、TCM、FIFO、ROM、寄存器堆 |
| 控制/FSM | #f8cecc | #b85450 | 状态机、控制器、时序生成 |
| 接口/IO | #d5e8d4 | #82b366 | AXI、总线接口、UART、SPI |
| 运算单元 | #e1d5e7 | #9673a6 | ALU、MAC、乘法器、算术单元 |
| 时钟/复位 | #ffe6cc | #d79b00 | 时钟源、PLL、复位生成器 |
| 寄存器/FF | #f5f5f5 | #666666 | 流水线寄存器、适配器/桥接器 |
| CDC/警告 | #FFCCCC | #FF0000 | 跨时钟域标记、错误/异常状态 |
| 总线矩阵 | #e1d5e7 | #9673a6 | 交叉开关、仲裁器、路由器 |

## 快速参考：连线颜色

| 信号类型 | strokeColor | strokeWidth | 线型 |
|----------|-------------|-------------|------|
| 数据总线 | #0066CC | 2 | 实线 |
| 控制信号 | #CC6600 | 1 | 实线 |
| 配置/CSR | #339933 | 1 | 虚线 |
| 时钟 | #CC0000 | 2 | 实线 |
| 复位 | #FF6600 | 2 | 虚线 (dashPattern=5 5) |
| CDC 路径 | #FF0000 | 1.5 | 虚线，双箭头 |
| 门控使能 | #999999 | 1 | 实线 |

## 快速参考：专用形状

| 元素 | shape 属性 | 说明 |
|------|-----------|------|
| 模块/子模块 | 无 (rounded=1) | 圆角矩形 |
| 存储器 | 无 (rounded=0) | 直角矩形 |
| 外部 DRAM | shape=cylinder3 | 圆柱体 |
| FSM 状态 | ellipse | 椭圆 |
| 初始状态 | ellipse + strokeWidth=2 | 粗边框椭圆 |
| 决策/分支 | rhombus | 菱形 |
| 时钟源 | shape=hexagon | 六边形 |
| 时钟门控 | shape=andGate | 与门形状 |
| 寄存器堆 | 无 (rounded=0) | 直角矩形+浅灰填充 |
| CDC 标记 | rounded=1 + arcSize=5 | 小圆角矩形+红色 |

---

## 阶段四：输出

将每张框图写入指定输出目录的 `.drawio` 文件：

```
output/<设计名>/
├── <设计名>_block_diagram.drawio    （模块框图）
├── <设计名>_dataflow.drawio         （数据流图）
├── <设计名>_control_flow.drawio     （控制流图）
└── <设计名>_clock_reset.drawio      （时钟复位图）
```

---

## 阶段五：生成报告

全部框图生成完毕后，打印汇总报告：

```
=== RTL 框图生成汇总 ===
源码路径: <路径>
设计类型: <SoC集成型 / CPU核型 / NPU加速器型 / 外设子系统型>
顶层模块: <模块名>
分析文件数: <数量>
发现子模块数: <数量>
发现 FSM 状态数: <数量>
时钟域数量: <数量>
总线协议: <AXI4 / TileLink / ICB / Wishbone>

生成框图:
  [✓] <路径>/<设计名>_block_diagram.drawio （N 个模块，M 条连线）
  [✓] <路径>/<设计名>_dataflow.drawio （P 个流水级，Q 条数据通路）
  [✓] <路径>/<设计名>_control_flow.drawio （R 个状态，S 个转移）
  [✓] <路径>/<设计名>_clock_reset.drawio （T 个时钟域，U 条时钟/复位路径）
```

---

## 图谱验证与官方文档对比方法

### 对比原则

生成框图后，应与以下来源进行对比验证：

1. **官方架构文档**：项目官网/README/DeepWiki 中描述的架构
2. **RTL 代码结构**：顶层模块的 `include` 和实例化层次
3. **官方框图**：官方提供的架构图/数据流图/时钟图

### 实际对比案例：NVDLA

基于对 NVDLA (github.com/nvdla/hw) 的分析，将自动生成的框图与官方文档 (nvdla.org/hw/v1/hwarch.html) 进行对比：

| 对比维度 | 官方文档描述 | 本工具自动生成 | 吻合度 |
|---------|------------|-------------|-------|
| **顶层分区** | 5 分区: A(CSB), C(卷积核), M(MAC阵列, ×2实例), O(后处理), P(基础设施) | 完整识别所有分区及内部子模块，标注双实例 | ✓ 完全吻合 |
| **卷积流水线** | CDMA→CBUF→CSC→CMAC→CACC (5级) | 完整绘制 5 级流水线及级间接口 | ✓ 完全吻合 |
| **后处理流水线** | SDP→PDP/CDP→RUBIK→BDMA | 完整绘制并区分融合/独立模式 | ✓ 完全吻合 |
| **卷积操作层次** | Atomic→Stripe→Block→Channel→Group (5层嵌套) | 完整绘制嵌套循环及数据流 | ✓ 完全吻合 |
| **工作模式** | 融合模式 (Fused) vs 独立模式 (Independent) | 两种模式均绘制并说明差异 | ✓ 完全吻合 |
| **时钟域** | 2 域: dla_core_clk + dla_csb_clk | 2 域 + 门控 + 电源管理 | ✓ 完全吻合 |
| **寄存器接口** | CSB (Configuration Space Bus) 协议 | 绘制 CSB 配置流程和 valid/ready 握手 | ✓ 完全吻合 |
| **Winograd 加速** | 3×3 卷积 2.25× MAC 效率 | 绘制 Winograd 变换流程 | ✓ 完全吻合 |
| **外部接口** | DBBIF (DRAM), SRAMIF (片上 SRAM) | 标注 AXI4 接口及信号名 | ✓ 完全吻合 |
| **SLCG 时钟门控** | Second-Level Clock Gating | 识别并标注门控层次 | ✓ 部分吻合 |

### 主要差异及改进方向

1. **MCIF/CVIF 接口细节**：官方文档将 NOCIF 明确分为 MCIF (Memory Controller IF) 和 CVIF (CVSRAM IF)，本工具将其合并在 NOCIF 中。**改进**：应识别 `_mcif_` 和 `_cvif_` 前缀的总线信号，将其作为独立子接口标注。

2. **CDMA 双通道**：CDMA 内部有 `dat` (数据) 和 `wt` (权重) 两个独立通道，应在数据流图中明确区分。**改进**：识别 `cdma_dat_*` 和 `cdma_wt_*` 信号前缀，标注为两个独立数据通路。

3. **CBUF Bank 结构**：官方文档描述 CBUF 有 16 个 Bank 的微架构，而自动提取仅能识别顶层模块。**改进**：对于代码中配置参数 `NUM_BANK=16` 等情况，应在标注中加入 Bank 数量。

4. **SDP 内部 X/Y 通道**：官方文档显示 SDP 内部有 X (主数据) 和 Y (逐元素操作数) 两个独立通道。**改进**：识别 `sdp_rdma` 和 `sdp_*` 子模块的内部信号命名模式。

5. **系统集成视角**：官方文档包含 NVDLA 在 SoC 中的集成框图（CPU→CSB，DRAM→DBBIF，SRAM→SRAMIF），本工具侧重于 IP 内部。**改进**：增加外部连接的一级，标注 SoC 集成界面。

### 从对比中提炼的通用作图经验

1. **自动生成代码的命名约定极其重要**：NVDLA 使用一致的信号前缀（`cdma_dat_*`、`sc2mac_*`、`cacc2sdp_*`），这些前缀直接揭示了模块间数据流关系。解析时应当：
   - 提取所有信号名的公共前缀作为"虚拟通道"标识
   - 将这些通道在数据流图中标注为独立路径
   
2. **参数化配置应在图中标注**：如 `N=4 lanes`、`16 MAC Cells × 64 MACs`、`512KB CBUF`，这些参数决定了设计的规模感。

3. **多实例标注要明确**：`partition_m ×2` 表示两个相同的 MAC 阵列实例，应在框图中明确标注。

4. **操作层次是 NPU 的核心**：卷积加速器的嵌套循环层次（atomic→stripe→block→channel→group）是其控制流的精髓，必须完整呈现。

5. **双模式架构需要并列展示**：融合模式和独立模式应并列绘制，标注 FIFO 直连 vs DRAM 往返的关键区别。

---

## 补充：NPU/加速器专用识别模式

基于 NVDLA、Coral NPU 等真实设计，补充以下 RTL 识别模式：

### NPU 卷积加速器特征

| 特征 | 识别模式 | 常见信号/模块名 |
|------|---------|---------------|
| MAC 阵列 | ××2 实例化，大量并行数据线 | `sc2mac_dat_*` (128-256 线), `mac2acc_*` |
| 序列控制器 | 嵌套循环参数 (R, S, C, K, W, H) | `csc`, `sequencer`, `*_loop_*` |
| 卷积缓冲区 | 大容量 SRAM，多 Bank | `cbuf`, `*_buffer`, `NUM_BANK` |
| 累加器 | 部分和存储，跨通道/跨块累加 | `cacc`, `accumulator`, `partial_sum` |
| 逐点处理器 | Bias/BN/激活函数 | `sdp`, `single_data_processor`, `bias`, `prelu` |
| 平面/通道处理器 | Pooling/LRN | `pdp`, `cdp`, `pooling`, `lrn` |
| Winograd 加速 | 4×4 tile 变换 | `winograd`, `f_4x4`, `transform` |
| DMA 双通道 | 数据 + 权重独立搬运 | `cdma_dat_*` + `cdma_wt_*` |
| 融合模式 | 内部 FIFO 直连 | `*2*_fifo`, `fused_mode`, 连线上无 DRAM 信号 |

### 识别 CSB/配置总线

```
csb2*_req_pvld / csb2*_req_prdy / csb2*_req_pd
*2csb_resp_*_valid / *2csb_resp_*_pd
```

### 识别中断信号

```
*_done_intr_* / *2glb_done_intr_*
dla_intr / *2cpu_irq
```
