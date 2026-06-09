# RISC-V CPU 学习项目

基于 RISC-V ISA 学习 CPU 基础知识的系统性学习项目。从指令集架构入门，到使用 Verilog 实现一个可运行 RV32I 指令的单周期处理器。

## 学习路线图

```
阶段一：RISC-V ISA 基础  ──→  阶段二：数字逻辑基础  ──→  阶段三：CPU 微架构  ──→  阶段四：动手实现
    (notes/01)                  (notes/02)                 (notes/03)               (rtl/ + sim/)
```

### 阶段一：RISC-V ISA 基础
理解指令集架构概念，掌握 RISC-V RV32I 指令格式、寄存器模型和汇编基础。
- 📖 笔记：[notes/01-isa-basics.md](notes/01-isa-basics.md)
- 📋 速查：[refs/instructions-reference.md](refs/instructions-reference.md)

### 阶段二：数字逻辑基础
理解组合逻辑、时序逻辑、状态机，掌握 Verilog 硬件描述语言基础。
- 📖 笔记：[notes/02-digital-logic.md](notes/02-digital-logic.md)

### 阶段三：CPU 微架构
理解数据通路与控制通路，掌握单周期处理器五级流水设计。
- 📖 笔记：[notes/03-microarchitecture.md](notes/03-microarchitecture.md)
- 📖 笔记：[notes/04-pipeline.md](notes/04-pipeline.md)

### 阶段四：实践
用 Verilog 实现一个 RV32I 单周期处理器，编写测试并仿真验证。
- 🔧 RTL：[rtl/](rtl/)
- 🧪 仿真：[sim/](sim/)

## 环境配置

### 必需工具

| 工具 | 用途 | 安装方式 |
|------|------|----------|
| **Icarus Verilog** (iverilog) | Verilog 仿真器 | `winget install iverilog` 或 [官网下载](https://bleyer.org/icarus/) |
| **GTKWave** | 波形查看器 | `winget install gtkwave` 或 [官网下载](https://gtkwave.sourceforge.net/) |
| **RISC-V GNU Toolchain** | 交叉编译（C → RISC-V） | [riscv-gnu-toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain) |
| **Spike** | RISC-V ISA 参考模拟器 | [riscv-isa-sim](https://github.com/riscv-software-src/riscv-isa-sim) |

### Windows 快速配置

```powershell
# 运行环境配置脚本
.\tools\setup.ps1
```

### Linux/Mac 快速配置

```bash
# 运行环境配置脚本
bash tools/setup.sh
```

## 快速开始

### 方式一：C 语言编程 + Verilog 仿真（推荐）

```bash
# 1. 编写 C 程序并编译为 RISC-V 裸机程序
cd sw
make              # 编译所有 C 程序
make dis          # 查看反汇编（理解 C→汇编→机器码的过程）

# 2. 回到仿真目录
cd ../sim
make run_tb_alu       # ALU 单元测试
make run_tb_core      # 完整处理器测试（加载 sw 中的 hex 程序）

# 3. 查看波形
make wave_tb_core
```

**完整工作流：C 源码 → RISC-V 机器码 → 处理器仿真**

```
sw/hello.c ──→ riscv-gcc ──→ hello.elf ──→ objcopy+elf2hex.py ──→ hello.hex
                                                                        │
                                                                        v
                                                          rtl/*.v ──→ iverilog ──→ 仿真波形
```

### 方式二：Verilog 仿真（手写汇编/机器码）

```bash
cd sim
make                # 编译所有模块
make run_tb_alu     # 运行 ALU 单元测试
make run_tb_core    # 运行完整处理器测试
make wave_tb_core   # 查看波形
```

## 项目结构

```
riscv/
├── notes/              # 学习笔记（按阶段编排）
├── refs/               # 参考资料与速查表
├── sw/                 # C 语言测试程序
│   ├── hello.c         # 裸机 Hello World
│   ├── fibonacci.c     # 斐波那契计算
│   ├── add_test.c      # 算术运算测试
│   ├── startup.s       # 启动代码（CRT0）
│   └── link.ld         # 链接脚本
├── rtl/                # RTL 设计源码
│   ├── core/           # 处理器核心模块
│   └── soc/            # SoC 集成
├── sim/                # 仿真与测试
│   ├── tb/             # Testbench
│   └── asm/            # 测试汇编程序
└── tools/              # 环境配置与辅助脚本
    ├── setup.sh / setup.ps1   # 环境配置脚本
    ├── Makefile               # 仿真自动化
    └── elf2hex.py             # ELF → Verilog hex 转换
```

## 参考资源

- [RISC-V 官方规范](https://riscv.org/technical/specifications/)
- [RISC-V 汇编手册](https://github.com/riscv-non-isa/riscv-asm-manual)
- [Digital Design and Computer Architecture: RISC-V Edition](https://www.elsevier.com/books/digital-design-and-computer-architecture-risc-v-edition/harris/978-0-12-820064-3) (Harris & Harris)
- [Computer Organization and Design: RISC-V Edition](https://www.elsevier.com/books/computer-organization-and-design-risc-v-edition/patterson/978-0-12-820331-6) (Patterson & Hennessy)
- 更多链接见 [refs/links.md](refs/links.md)
