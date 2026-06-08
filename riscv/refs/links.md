# 外部学习资源

## 官方规范与文档

- **RISC-V 非特权规范 (Unprivileged Specification)** — RV32I/RV64I 及所有标准扩展的权威文档
  https://riscv.org/technical/specifications/
  
- **RISC-V 特权规范 (Privileged Specification)** — 机器模式、监管者模式、CSR 定义
  https://riscv.org/technical/specifications/

- **RISC-V 汇编程序员手册 (RISC-V Assembly Programmer's Manual)**
  https://github.com/riscv-non-isa/riscv-asm-manual

## 教材（推荐阅读顺序）

1. **《Digital Design and Computer Architecture: RISC-V Edition》** — Harris & Harris (2021)
   最推荐的自学教材。从数字电路讲到 RISC-V 处理器设计，手把手教你用 SystemVerilog 实现一个完整的 RISC-V CPU。
   
2. **《Computer Organization and Design: RISC-V Edition》** — Patterson & Hennessy
   经典的 "Patterson & Hennessy" 教材，偏重指令集和微架构概念。与 Harris & Harris 互补。

3. **《The RISC-V Reader: An Open Architecture Atlas》** — David Patterson & Andrew Waterman
   RISC-V 设计者的权威解读，薄而精，适合快速通读。

## 在线课程

- **MIT 6.004: Computation Structures** — MIT 的经典数字系统课程（公开课件）
  https://ocw.mit.edu/courses/6-004-computation-structures-spring-2017/

- **UC Berkeley CS61C: Great Ideas in Computer Architecture** — 伯克利的计算机架构课（RISC-V 版本）
  https://cs61c.org/

- **"From NAND to Tetris" (nand2tetris)** — 构建一台完整的计算机，适合零基础入门
  https://www.nand2tetris.org/

## RTL 开源参考实现

- **Rocket Chip Generator** — UC Berkeley 开发的 RISC-V 处理器生成器（Chisel）
  https://github.com/chipsalliance/rocket-chip

- **PicoRV32** — 极简 RV32I 处理器（Verilog，~1000 行），非常适合学习
  https://github.com/YosysHQ/picorv32

- **SERV** — 世界上最小的 RISC-V 处理器（~300 LUT），bit-serial 实现
  https://github.com/olofk/serv

- **RI5CY / CV32E40P** — 精简高效的 4 级流水 RV32IMC 核心（SystemVerilog）
  https://github.com/openhwgroup/cv32e40p

## 工具

- **RISC-V GNU Toolchain** — GCC 交叉编译器
  https://github.com/riscv-collab/riscv-gnu-toolchain

- **Spike** — RISC-V 黄金参考模拟器
  https://github.com/riscv-software-src/riscv-isa-sim

- **Icarus Verilog** — 开源 Verilog 仿真器
  https://github.com/steveicarus/iverilog

- **Verilator** — 高速 Verilog 仿真器（Verilog → C++）
  https://github.com/verilator/verilator

- **GTKWave** — 开源波形查看器
  https://github.com/gtkwave/gtkwave

- **RISC-V Online Assembler** — 在线 RISC-V 汇编器
  https://riscvasm.lucasteske.dev/

- **Venus** — RISC-V 在线模拟器/调试器
  https://venus.cs.berkeley.edu/

## 学习路径参考

- **RISC-V Learn (riscv.org)** — 官方整理的系列学习资源
  https://riscv.org/learn/

- **RISC-V 指令集卡片 (参考卡片)**
  https://www.cl.cam.ac.uk/teaching/1617/ECAD+Arch/files/docs/RISCVGreenCardv8-20151013.pdf

## 中文资源

- **《计算机组成与设计：RISC-V版》（中文译本）**
  机械工业出版社出版，Patterson & Hennessy 经典教材的中文版

- **一生一芯 (One Student One Chip)** — 中科院计算所开源人才培养项目
  https://ysyx.oscc.cc/
