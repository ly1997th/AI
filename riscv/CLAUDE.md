# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个 RISC-V CPU 学习项目，目标是：
1. 系统性学习 RISC-V ISA（RV32I）和 CPU 微架构
2. 用 Verilog 实现一个单周期 RISC-V 处理器
3. 通过仿真验证处理器正确性

学习笔记在 `notes/` 中，参考资料在 `refs/` 中，RTL 实现在 `rtl/` 中。

## 常用命令

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

## 项目约定

### Verilog 编码规范
- 模块名使用小写+下划线（`control_unit`, `reg_file`）
- 信号名使用小写+下划线（`alu_result`, `reg_write_data`）
- 参数使用大写+下划线（`DATA_WIDTH`, `ADDR_WIDTH`）
- 每个模块一个文件，文件名 = 模块名 + `.v`
- 组合逻辑用 `assign`，时序逻辑用 `always @(posedge clk)`

### 文件组织
- `rtl/core/` — 处理器核心模块（可综合）
- `rtl/soc/` — SoC 集成层（顶层 + 存储器）
- `sim/tb/` — Testbench（不可综合，仅仿真用）
- `sim/asm/` — RISC-V 汇编测试程序
- 仿真产物（`.vcd`, `.vvp`）在 `sim/` 目录，由 `.gitignore` 忽略

### 开发流程
1. 先阅读对应阶段的笔记（`notes/`）
2. 查看参考资料（`refs/`）获取详细规格
3. 编写/修改 RTL 模块（`rtl/core/`）
4. 编写 testbench 验证模块行为（`sim/tb/`）
5. `cd sim && make run_tb_<module>` 运行仿真
6. `make wave_tb_<module>` 查看波形调试

## 关键参考文件

- [refs/instructions-reference.md](refs/instructions-reference.md) — 全部 RV32I 指令编码速查表
- [refs/riscv-spec-summary.md](refs/riscv-spec-summary.md) — RISC-V 规范核心摘要
- [refs/links.md](refs/links.md) — 外部学习资源
- [notes/01-isa-basics.md](notes/01-isa-basics.md) — ISA 基础笔记
- [notes/03-microarchitecture.md](notes/03-microarchitecture.md) — 微架构详细设计
