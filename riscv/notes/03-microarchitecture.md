# 阶段三：CPU 微架构

> **以宏单元为积木，搭建完整的 RISC-V 处理器数据通路。**

## 1. 架构 vs 微架构

| | 架构 (Architecture) | 微架构 (Microarchitecture) |
|---|-------------------|-------------------------|
| 本质 | 软件接口契约 | 硬件实现方案 |
| 例子 | RISC-V RV32I（定义了 ADD 等指令的编码和行为） | 单周期/流水线/超标量（不同的硬件实现） |
| 对应宏单元 | 无（纯规范定义） | PC(DFF) + RegFile(DFF阵列+MUX) + ALU(Adder+Shifter+MUX) + ... |

同一个 RISC-V ISA 可以有完全不同的微架构——这是理解"架构"与"微架构"分离的核心。

## 2. 四维通路分离视角下的处理器

在设计处理器数据通路之前，先按**多维度通路分离原则**将整个处理器划分为四条独立通路：

### 2.1 数据通路（32-bit 核心数据流）

```
PC ─→ I-MEM ─→ instr ─→ RegFile(rd1,rd2) ─→ ALU ─→ D-MEM ─→ MemtoReg MUX ─→ RegFile(wd3)
```

- **位宽**：32-bit（全路径最宽）
- **目标**：低延迟（决定时钟周期）
- **关键瓶颈**：RegFile 读 MUX 级联（5级）+ ALU 进位链（~10级）+ D-MEM 读延迟
- **单周期关键路径**：PC→I-MEM→译码→RegFile读→ALU→D-MEM→MUX→RegFile写

### 2.2 地址通路（寻址信号）

| 地址信号 | 来源 | 去向 | 位宽 | 扇出 |
|----------|------|------|------|------|
| 指令地址 | PC | I-MEM.addr | 32-bit | 1 |
| 数据地址 | ALU result | D-MEM.addr | 32-bit | 1 |
| 读寄存器地址 rs1 | instr[19:15] | RegFile.a1 | 5-bit | 1 |
| 读寄存器地址 rs2 | instr[24:20] | RegFile.a2 | 5-bit | 1 |
| 写寄存器地址 rd | instr[11:7] | RegFile.a3 | 5-bit | 1 |

> 地址通路扇出看似为 1，但在 RegFile 内部，5-bit 地址经 5:32 译码器后扇出至 32 根字线（每根字线驱动 32 个 bit-cell），这是内部高扇出的核心。

### 2.3 参数通路（立即数 / 常量）

```
instr ─→ imm_gen ─→ imm[31:0]
                        ├──→ ALU src MUX（I/S/B/U/J 型指令的立即数操作数）
                        ├──→ PC Adder（分支/跳转偏移量）
                        └──→ next_pc MUX 选择（跳转目标地址）
```

- **特点**：变化频率 = 每周期（新指令 → 新立即数），但仅特定指令类型使用
- **优化空间**：U-type 的 12'b0 填充可通过硬布线实现（零门逻辑）

### 2.4 控制通路（控制信号）

```
                    ┌─→ reg_write  → RegFile.we3
opcode ─→ Control ─┤─→ alu_src    → ALU src MUX select
         Unit      ├─→ mem_write  → D-MEM.we
         (Decoder) ├─→ mem_read   → D-MEM.re
                   ├─→ mem_to_reg → MemtoReg MUX select
                   ├─→ branch/jump/jump_reg → next_pc MUX select
                   ├─→ alu_op     → ALU Decoder
                   └─→ alu_control → ALU operation select
```

- **位宽**：每条控制信号 1-4 bit（极小）
- **扇出**：点对点（1:1），无高扇出问题
- **面积**：~80 门当量（仅占总面积 1-3%）

## 3. 宏单元级数据通路设计

### 3.1 顶层拓扑（宏单元 + 连线）

```
                          instr[31:0]
┌──────┐   pc[31:0]   ┌──────────┐   │   ┌───────────────┐
│  PC  │─────────────→│ I-Memory │───┼──→│ Control Unit  │
│(DFF) │←──┐          │ (外部SRAM)│   │   │  (Decoder)    │
└──────┘   │          └──────────┘   │   └───┬───┬───┬───┘
    ↑      │                         │       │   │   │
    │   ┌──┴──────────┐              │       │   │   │  控制信号
    │   │ next_pc MUX │              │   ┌───┘   │   └──────┐
    │   │  (4-to-1)   │              │   │       │          │
    │   └──────┬───────┘              │   │       │          │
    │          ↑                      │   │       │          │
    │   跳转目标地址                   │   │       │          │
    │                                 │   │       │          │
    │                            ┌────┴───┴──┐    │          │
    │              rs1_addr ───→ │ Register  │    │          │
    │              rs2_addr ───→ │   File    │←───┘          │
    │                           │ (DFF阵列   │               │
    │                           │  + 译码器  │               │
    │                           │  + MUX网络)│               │
    │                           └──┬───┬────┘               │
    │                         rd1  │   │ rd2                │
    │                              ↓   ↓                    │
    │                         ┌──────────────┐              │
    │                         │ ALU src MUX  │←─────────────┘
    │                         │  (2-to-1)    │   alu_src
    │                         └──┬──────┬────┘
    │                       alu_a│      │alu_b
    │                            ↓      ↓
    │                       ┌──────────────┐
    │                       │     ALU      │←──── alu_control[3:0]
    │                       │ (Adder+Shift │
    │                       │  +MUX树)     │
    │                       └──────┬───────┘
    │                              │ alu_result
    │                              ↓
    │                       ┌──────────────┐
    │                       │  D-Memory    │←── mem_write/mem_read
    │                       │  (外部SRAM)  │
    │                       └──────┬───────┘
    │                              │
    │                       ┌──────┴───────┐
    │                       │MemtoReg MUX  │←── mem_to_reg
    │                       │  (2-to-1)    │
    │                       └──────┬───────┘
    │                              │ wd3
    │                              └──→ RegFile.wd3
    │
    └────────────────────────────────┘
```

### 3.2 宏单元清单（单周期 RV32I 处理器）

| 宏单元 | 实例化于 | 数量 | 面积估算 | 时序 |
|--------|----------|------|---------|------|
| DFF（32-bit） | PC | 32 | ~192 门当量 | CK→Q ≈ 1 DFF 延迟 |
| DFF 阵列（1024） | RegFile | 1024 | ~3000 门当量 | 最大面积贡献者 |
| 5:32 Decoder | RegFile | 3 | ~100 门当量 | 1级逻辑 |
| 32-to-1 MUX（32-bit） | RegFile 读端口 | 2 | ~600 门当量 | 5级 MUX 级联 |
| Adder（32-bit） | ALU / PC+4 | 1 | ~200 门当量 | ~10级进位链 |
| Barrel Shifter | ALU | 1 | ~300 门当量 | ~5级 MUX 网络 |
| 10-to-1 MUX（32-bit） | ALU | 1 | ~300 门当量 | 4级 MUX 级联 |
| 7:10 Decoder | Control Unit | 1 | ~50 门当量 | 1-2级逻辑 |
| 4-to-1 MUX（32-bit） | Core next_pc | 1 | ~200 门当量 | 2级 MUX 级联 |
| 2-to-1 MUX（32-bit） | Core ×3 | 3 | ~300 门当量 | 1级 MUX |
| SRAM（仿真） | Memory | 1 | N/A (仿真) | 读≈1-3ns |

> **PPA 精度分级**：以上为**低敏感度—基于逻辑分析**估算，用于架构探索阶段。

### 3.3 互联关系中的高扇出与重汇聚标注

| 信号 | 类型 | 扇出 | 风险 | 应对 |
|------|------|------|------|------|
| instr[31:0] | 数据 | 3（CtrlUnit + imm_gen + regfile addr） | 低 | 扇出小，无需缓冲 |
| pc[31:0] | 地址 | 2（I-MEM + PC+4 Adder） | 低 | 常规 |
| reg_write | 控制 | 1（RegFile.we3） | 低 | 点对点 |
| alu_result | 数据 | 3（D-MEM + next_pc + MemtoReg） | 中 | 关键路径分支点，需平衡负载 |
| 字线（RegFile 内部） | 地址 | 32（bit-cell / 字线） | **高** | 需缓冲树！ |

## 4. 控制通路译码树（两级译码结构）

控制单元的译码逻辑设计展示了**组合逻辑打平原则**的应用：

```
第一级：主译码器（7:10 Decoder）
  opcode[6:0] ──→ {reg_write, alu_src, mem_write, mem_read,
                    mem_to_reg, branch, jump, jump_reg, alu_op[1:0]}

第二级：ALU 译码器（组合 LUT）
  {alu_op[1:0], funct3[2:0], funct7_5} ──→ alu_control[3:0]
```

> 为什么是两级而不是一级？因为 ALU 操作码需要 funct3/funct7 辅助译码，而 Load/Store/Branch 不需要。两级分离避免了主译码器的过度膨胀，且 alu_op 仅 2-bit，级联代价极小。

## 5. 性能分析：单周期的局限

### 5.1 关键路径分析

```
T_clk ≥ T_pc_ck2q + T_imem_read + T_decoder + T_regfile_read
       + T_alu + T_dmem_read + T_mux + T_regfile_setup
```

各段的延迟贡献（典型值）：
- PC CK→Q：~0.1ns（DFF 延迟）
- I-MEM 读：~1-3ns（SRAM 访问延迟，**最大的单一延迟**）
- 译码 + RegFile 读：~0.3ns（组合逻辑）
- ALU：~0.5ns（进位链 + MUX）
- D-MEM 读：~1-3ns（SRAM 访问延迟，**第二大延迟**）
- MUX + Setup：~0.2ns

> **结论**：SRAM 访问延迟主导了时钟周期。`lw` 需要两次 SRAM 访问（I-MEM + D-MEM），是单周期处理器中最慢的指令。

### 5.2 为什么需要流水线

单周期设计的根本矛盾：
- 每条指令只用一个周期（CPI=1 看起来很好）
- 但周期长度由最慢指令（lw：~7ns）决定
- `add` 只需要 ~3ns，却要等整整 7ns

流水线的核心思想：将长延迟路径切分为短段，每段用寄存器隔开，让不同指令的段在同一时刻并行执行（详见 [阶段四：流水线](04-pipeline.md)）。

## 6. 从电路拓扑到 RTL 代码

### 6.1 强制输出格式

按照 rtl_design_rule.md 的要求，每个模块的文档均遵循：

```
### 1. 电路架构
[使用宏单元术语描述电路拓扑，区分数据/地址/参数/控制通路]

### 2. 宏单元映射与PPA评估
[显式列出宏单元、互联关系、PPA代价（标注精度分级）]

### 3. RTL代码
[严格依据上述电路架构的 Verilog 实现]
```

### 6.2 学习路径

1. 打开 [rtl/core/pc.v](../rtl/core/pc.v) — 最简单的模块，理解三段式结构
2. 打开 [rtl/core/alu.v](../rtl/core/alu.v) — 理解 MUX 树和关键路径
3. 打开 [rtl/core/regfile.v](../rtl/core/regfile.v) — 理解 DFF 阵列和地址译码高扇出
4. 打开 [rtl/core/control_unit.v](../rtl/core/control_unit.v) — 理解两级译码树
5. 打开 [rtl/core/core.v](../rtl/core/core.v) — **四维通路分离的完整展示**
6. 继续阅读下节的指令追踪实例

## 7. 指令追踪实例：add x3, x1, x2 的完整数据通路之旅

> **目标**：将抽象的数据通路图转化为头脑中的具体信号流动。以单条指令 `add x3, x1, x2` 为例，追踪从取指到写回的每一个步骤。

### 7.1 前提条件

- PC = 0x00000008（当前指令地址）
- x1 = 5, x2 = 3（前两条 addi 指令写入的值）
- 指令机器码 = 0x002081B3（已校验）

### 7.2 逐阶段追踪

#### 阶段 1：IF（取指令）

| 信号 | 来源 | 值 | 说明 |
|------|------|-----|------|
| `pc` | pc.v 输出 | 0x00000008 | 当前 PC 值 |
| `i_addr` | pc → memory | 0x00000008 | 指令存储器地址 |
| `instr_i` | memory → core | **0x002081B3** | 取出的 32-bit 指令 |

```
pc(0x08) ──→ I-MEM[0x08] ──→ instr=0x002081B3
```

#### 阶段 2：ID（指令译码 + 寄存器读取）

**指令字段提取**（core.v 中的 assign 语句，纯组合逻辑，零延迟）：

| 字段 | 提取方式 | 值 | RISC-V 含义 |
|------|----------|-----|-------------|
| `opcode[6:0]` | instr[6:0] | **0110011** | R-type ALU |
| `rd_addr[4:0]` | instr[11:7] | 00011 | 目标寄存器 = **x3** |
| `funct3[2:0]` | instr[14:12] | 000 | ADD/SUB |
| `rs1_addr[4:0]` | instr[19:15] | 00001 | 源寄存器1 = **x1** |
| `rs2_addr[4:0]` | instr[24:20] | 00010 | 源寄存器2 = **x2** |
| `funct7[6:0]` | instr[31:25] | 0000000 | ADD (非 SUB) |
| `funct7_5` | instr[30] | 0 | ADD 标志 |

**主译码器**（control_unit.v 第一级）：

| 输出信号 | 值 | 含义 |
|----------|-----|------|
| `reg_write` | **1** | R-type 要写回结果 |
| `alu_src` | **0** | ALU 第二操作数来自 rs2（非立即数） |
| `mem_write` | 0 | 不写内存 |
| `mem_read` | 0 | 不读内存 |
| `mem_to_reg` | 0 | 写回数据来自 ALU（非内存） |
| `branch` | 0 | 非分支 |
| `jump` | 0 | 非跳转 |
| `jump_reg` | 0 | 非间接跳转 |
| `alu_op[1:0]` | **10** | R-type → 需 funct3+funct7 进一步译码 |

**ALU 译码器**（control_unit.v 第二级）：

| 输入 | 值 |
|------|-----|
| alu_op | 10 |
| funct3 | 000 |
| funct7_5 | 0 |

→ `alu_control[3:0]` = **0000 (ADD)**

**寄存器文件读取**：

| 读端口 | 地址 | 读数据 | 说明 |
|--------|------|--------|------|
| 端口1 (a1) | 00001 (x1) | `rd1 = 0x00000005` | 5 |
| 端口2 (a2) | 00010 (x2) | `rd2 = 0x00000003` | 3 |

```
instr[19:15]=00001 → RegFile.a1 → 5:32 Decoder → wordline[1] → MUX → rd1=5
instr[24:20]=00010 → RegFile.a2 → 5:32 Decoder → wordline[2] → MUX → rd2=3
```

#### 阶段 3：EX（执行 — ALU 运算）

| 信号 | 来源 | 值 | 说明 |
|------|------|-----|------|
| `alu_a` | assign = rd1 | **0x00000005** | ALU 第一操作数 |
| `alu_b` | MUX(alu_src, rd2, imm) | **0x00000003** | ALU 第二操作数（选 rs2） |
| `alu_control` | control_unit | **0000 (ADD)** | 加法操作 |
| `alu_result` | ALU 输出 | **0x00000008** | 5 + 3 = 8 ✓ |
| `alu_zero` | NOR(result) | 0 | 结果非零 |

```
alu_a=5 ─┐
          ├─→ [32-bit Adder] ──→ alu_result=8 ──→ D-MEM.addr
alu_b=3 ─┘                                        ──→ next_pc MUX
                                                  ──→ MemtoReg MUX
```

#### 阶段 4：MEM（存储器访问 — 此指令无操作）

因为 `mem_write=0` 且 `mem_read=0`，此阶段为空操作。D-MEM 不响应。

```
mem_write=0 → D-MEM.we=0 → 无写操作
mem_read=0  → D-MEM.re=0 → 无读操作
alu_result=8 通过直连传递到下一阶段
```

#### 阶段 5：WB（写回）

| 信号 | 来源 | 值 | 说明 |
|------|------|-----|------|
| `wd3` | MUX(mem_to_reg, alu_result, mem_rdata) | **0x00000008** | 选 ALU 结果 |
| `reg_write` | control_unit | **1** | 写使能 |
| `a3` | instr[11:7] | **00011** | 目标寄存器 x3 |

```
wd3=8 ──→ RegFile.wd3
reg_write=1 ──→ RegFile.we3 ──→ AND (a3!=0) ──→ rf[3].WE
a3=00011 ──→ 5:32 Decoder ──→ wordline[3]=1
```

**posedge clk 时**：`rf[3] <= 8`，即 `x3 = 8`。

#### 阶段 6：PC 更新

因为 `branch=0`, `jump=0`, `jump_reg=0`：
- `next_pc = pc_plus_4 = 0x08 + 4 = 0x0C`
- posedge clk 时：`pc <= 0x0C`

### 7.3 总结：四条通路在此指令中的活动

| 通路 | 活动 | 关键信号 |
|------|------|----------|
| **数据通路** | 5 + 3 → 8 → 写回 x3 | instr, rd1, rd2, alu_result, wd3 |
| **地址通路** | PC→I-MEM, rs1_addr/rs2_addr→RegFile, rd_addr→RegFile | pc, rs1_addr, rs2_addr, rd_addr |
| **参数通路** | 无（R-type 不使用立即数） | — |
| **控制通路** | opcode→主译码→ALU译码→控制信号 | reg_write=1, alu_src=0, alu_control=ADD |

### 7.4 与 lw 指令的对比

| 信号 | add x3,x1,x2 | lw x3,0(x1) | 差异原因 |
|------|-------------|-------------|----------|
| alu_src | 0 (rs2) | 1 (imm) | lw 需要 imm 计算地址 |
| mem_read | 0 | 1 | lw 读内存 |
| mem_to_reg | 0 (ALU) | 1 (MEM) | lw 写回内存数据 |
| alu_op | 10 | 00 | lw 的 ALU 只做地址加法 |
| 关键路径 | IF→ID→EX→WB | IF→ID→EX→MEM→WB | lw 多一级 MEM 访问 |

## 8. 下一步

已经掌握了宏单元视角和数据通路设计方法论。进入 [阶段四：流水线](04-pipeline.md) 了解如何突破单周期性能瓶颈。
