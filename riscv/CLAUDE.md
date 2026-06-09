# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个 RISC-V CPU 学习项目，目标是：
1. 系统性学习 RISC-V ISA（RV32I）和 CPU 微架构
2. 用 Verilog 实现一个单周期 RISC-V 处理器
3. 通过仿真验证处理器正确性

学习笔记在 `notes/` 中，参考资料在 `refs/` 中，RTL 实现在 `rtl/` 中，C 程序在 `sw/` 中。

**强制设计方法论**：本项目严格遵循 `refs/rtl_design_rule.md` 的硬件优先原则。
所有 RTL 开发必须遵循 **电路架构 → 宏单元映射与PPA评估 → RTL代码** 三段式工作流。

## 常用命令

### C 语言交叉编译（RISC-V 裸机程序）

```bash
# 编译所有 C 程序并生成反汇编和 hex
cd sw && make

# 单独编译某个程序
cd sw && make hello        # hello world
cd sw && make fibonacci    # 斐波那契
cd sw && make add_test     # 算术测试

# 查看反汇编（理解 C 如何编译为 RISC-V 指令）
cd sw && make dis

# 提取 ELF 中的机器码为 Verilog hex 格式
cd sw && make hex

# 清理编译产物
cd sw && make clean
```

**C → RISC-V 完整编译流程：**

```
C 源码 (*.c)                GCC 交叉编译              ELF 可执行文件
    +                         ───────────>              (*.elf)
启动代码 (startup.s)
    +
链接脚本 (link.ld)

    ELF                         objcopy                   Hex 文件
  (*.elf)          ───────────>   elf2hex.py    ───────────>  (*.hex)
                                      │
                                      └── 加载到 Verilog 存储器仿真
```

**手动编译单个程序：**

```bash
# 1. 编译 C + 汇编 → ELF
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -T sw/link.ld \
    sw/startup.s sw/hello.c -o hello.elf

# 2. 反汇编（查看生成的 RISC-V 指令）
riscv64-unknown-elf-objdump -d hello.elf

# 3. 提取机器码为 hex（供 Verilog $readmemh 使用）
python3 tools/elf2hex.py hello.elf hello.hex
```

### 仿真（使用 Icarus Verilog + GTKWave）

```bash
# 编译所有模块
cd sim && make

# 运行单个 testbench
make run_tb_alu        # ALU 测试
make run_tb_regfile    # 寄存器文件测试
make run_tb_core       # 完整处理器测试

# 查看波形
make wave_tb_alu
make wave_tb_core

# 清理仿真产物
make clean
```

### RISC-V 工具链

```bash
# 编译 C 代码为 RISC-V 汇编/机器码
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -S -o output.s input.c
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -o output.elf input.c

# 反汇编
riscv64-unknown-elf-objdump -d output.elf

# 用 Spike 模拟运行
spike --isa=rv32i pk output.elf
```

### 查看 RISC-V 规范摘要

```bash
# 通过 Makefile 查看指令集信息
make help
```

## 架构说明

### RTL 模块层次结构

```
soc_top.v (SoC 顶层)
├── core.v (处理器核心 — 数据通路)
│   ├── pc.v (程序计数器)
│   ├── regfile.v (寄存器文件, 32×32bit)
│   ├── alu.v (算术逻辑单元)
│   ├── imm_gen.v (立即数生成器)
│   └── control_unit.v (控制单元 — 译码+控制信号)
└── memory.v (统一指令/数据存储器)
```

### 数据通路（单周期处理器）

单周期处理器的数据通路遵循经典五阶段：

1. **IF (Instruction Fetch)**: PC → 指令存储器 → 取出指令
2. **ID (Instruction Decode)**: 指令 → 控制单元译码 + 寄存器读取
3. **EX (Execute)**: ALU 运算 / 地址计算 / 分支判断
4. **MEM (Memory)**: 数据存储器读写（load/store）
5. **WB (Write Back)**: 结果写回寄存器文件

在单周期设计中，所有阶段在同一时钟周期内完成。每条指令执行完后 PC 更新为下一条指令地址。

### RISC-V RV32I 指令格式

| 格式 | 位布局 | 典型指令 |
|------|--------|----------|
| R-type | funct7[31:25] + rs2[24:20] + rs1[19:15] + funct3[14:12] + rd[11:7] + opcode[6:0] | add, sub, and, or, xor, sll, srl, slt |
| I-type | imm[31:20] + rs1[19:15] + funct3[14:12] + rd[11:7] + opcode[6:0] | addi, lw, jalr |
| S-type | imm[11:5] + rs2[24:20] + rs1[19:15] + funct3[14:12] + imm[4:0] + opcode[6:0] | sw |
| B-type | imm[12|10:5] + rs2[24:20] + rs1[19:15] + funct3[14:12] + imm[4:1|11] + opcode[6:0] | beq, bne, blt, bge |
| U-type | imm[31:12] + rd[11:7] + opcode[6:0] | lui, auipc |
| J-type | imm[20|10:1|11|19:12] + rd[11:7] + opcode[6:0] | jal |

### 控制信号一览

| 信号 | 说明 | 来源 |
|------|------|------|
| RegWrite | 写使能寄存器文件 | control_unit |
| ALUSrc | ALU 第二操作数选择 (0=rs2, 1=imm) | control_unit |
| MemWrite | 数据存储器写使能 | control_unit |
| MemRead | 数据存储器读使能 | control_unit |
| MemtoReg | 写回数据选择 (0=ALU结果, 1=内存数据) | control_unit |
| Branch | 分支指令标志 | control_unit |
| ALUOp | ALU 操作码 | control_unit |

## 设计方法论（强制）

本项目严格遵循 [refs/rtl_design_rule.md](refs/rtl_design_rule.md) 中定义的 IC 逻辑设计规范。

### 强制工作流（修改任何 RTL 模块前必须执行）

1. **需求分解** — 明确输入输出端口、时序约束和功能目标
2. **电路拓扑设计** — 使用宏单元词典（DFF/MUX/Decoder/Adder等）描述电路架构，**必须区分数据通路、地址通路、参数通路与控制通路**，明确各节点扇入扇出关系
3. **宏单元映射与PPA评估** — 显式列出宏单元及互连关系，标注高扇出与重汇聚点，评估PPA代价（标注精度分级：低/中/高敏感度）
4. **HDL代码实现** — 严格依据第2、3步的电路结构编写RTL

### 核心思维准则

| 准则 | 内容 | 反例 |
|------|------|------|
| **空间切片** | 压住时间，铺开空间，罗列所有场景再化解 | 单线程追踪变量在不同时刻的值 |
| **通路分离** | 将电路拆解为数据/地址/参数/控制四通路 | 所有信号混杂黑盒描述 |
| **PPA意识** | NAND/NOR最基础，AND/OR需额外反相器，MUX远贵于门 | 视逻辑等价为物理等价 |
| **扇出警觉** | 地址通路高扇出 → 预留缓冲树；重汇聚 → 防毛刺 | 忽略信号负载与线延迟 |
| **组合打平** | 多级MUX树降维为地址面代数计算，数据面仅留末级 | 保留级联冗余致面积膨胀 |

### HDL编码准则（电路映射）
- `if-else` / `case` = **MUX拓扑**（避免深层嵌套防长时序路径）
- `=` = **组合逻辑**（连续赋值或组合逻辑块阻塞赋值）
- `<=` = **时序逻辑DFF**（时序逻辑块非阻塞赋值）
- FSM = **DFF（状态寄存器） + 译码器（次态逻辑） + MUX（输出逻辑）**
- 条件赋值 = **ICG拓扑（时钟使能）** 或 **带反馈的MUX（数据使能）**

### Verilog 编码规范
- 模块名使用小写+下划线（`control_unit`, `reg_file`）
- 信号名使用小写+下划线（`alu_result`, `reg_write_data`）
- 参数使用大写+下划线（`DATA_WIDTH`, `ADDR_WIDTH`）
- 每个模块一个文件，文件名 = 模块名 + `.v`
- 每个模块的文件头必须包含 **电路架构→宏单元映射与PPA评估→RTL代码** 三段注释

### 文件组织
- `sw/` — C 语言测试程序（裸机，无 OS 依赖）
- `sw/link.ld` — 链接脚本（定义内存布局）
- `sw/startup.s` — 启动代码（设置栈、清零 BSS、调 main）
- `rtl/core/` — 处理器核心模块（可综合）
- `rtl/soc/` — SoC 集成层（顶层 + 存储器）
- `sim/tb/` — Testbench（不可综合，仅仿真用）
- `sim/asm/` — RISC-V 汇编测试程序
- `tools/elf2hex.py` — ELF → hex 转换工具
- 仿真产物（`.vcd`, `.vvp`）在 `sim/` 目录，由 `.gitignore` 忽略

### 开发流程（完整链路）
1. 阅读对应阶段的笔记（`notes/`），理解微架构概念
2. 查阅 [refs/rtl_design_rule.md](refs/rtl_design_rule.md) 确认设计方法论
3. **电路拓扑设计**：按四维通路分离原则画出宏单元拓扑（可用文字描述）
4. **编写 C 程序 + 交叉编译生成 RISC-V 指令**（`sw/` 目录）作为测试向量
5. 编写/修改 RTL 模块（`rtl/core/`），严格按三段式结构（电路架构→PPA→代码）
6. 编写 testbench 验证模块行为（`sim/tb/`）
7. `cd sim && make run_tb_<module>` 运行仿真
8. `make wave_tb_<module>` 查看波形调试

## 关键参考文件

- [refs/rtl_design_rule.md](refs/rtl_design_rule.md) — **IC逻辑设计规范（强制阅读）**
- [refs/instructions-reference.md](refs/instructions-reference.md) — 全部 RV32I 指令编码速查表
- [refs/links.md](refs/links.md) — 外部学习资源
- [notes/01-isa-basics.md](notes/01-isa-basics.md) — ISA 基础笔记
- [notes/02-digital-logic.md](notes/02-digital-logic.md) — 数字逻辑与硬件思维
- [notes/03-microarchitecture.md](notes/03-microarchitecture.md) — 微架构（四维通路分离 + 宏单元映射）
