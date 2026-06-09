# RISC-V RV32I 规范核心摘要

> 本文是 [RISC-V Unprivileged Specification](https://riscv.org/technical/specifications/) 的核心内容精炼，聚焦于本项目（单周期 RV32I 处理器）所需的关键知识点。

## 1. 处理器状态 (Processor State)

RV32I 处理器可见的程序员状态包括：

| 状态 | 位宽 | 数量 | 说明 |
|------|------|------|------|
| 通用寄存器 (GPR) | 32-bit | 32 个 (x0–x31) | x0 硬连线为 0 |
| 程序计数器 (PC) | 32-bit | 1 个 | 当前指令地址，4 字节对齐 |
| 内存 | 8-bit 寻址 | 2^32 字节 | 小端字节序 (Little-Endian) |

**无状态寄存器 (FLAGS)**：RISC-V 没有条件码寄存器（与 x86/ARM 不同）。分支指令直接比较寄存器值并跳转，所有运算在单条指令内完成"运算 + 判断"。

## 2. 地址空间

```
0x0000_0000 ─┬─ .text (代码段)
             │
             ├─ .rodata (只读数据)
             │
             ├─ .data (已初始化数据)
             │
             ├─ .bss (未初始化数据)
             │
             ├─ heap (堆，向上增长)
             │
             ├─ ...
             │
             ├─ stack (栈，向下增长)
             │
0xFFFF_FFFF ─┴─ MMIO (内存映射 I/O)
```

本项目的仿真环境使用简化的统一地址空间：代码和数据均从地址 0 开始，栈顶设在 `0x00004000`。

## 3. 指令编码速览

### opcode 映射

| opcode[6:0] | 指令类别 | 代表指令 |
|-------------|----------|----------|
| `0110111` | U-type | LUI |
| `0010111` | U-type | AUIPC |
| `1101111` | J-type | JAL |
| `1100111` | I-type | JALR |
| `1100011` | B-type | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| `0000011` | I-type | LB, LH, LW, LBU, LHU |
| `0100011` | S-type | SB, SH, SW |
| `0010011` | I-type | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI |
| `0110011` | R-type | ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND |
| `0001111` | I-type | FENCE, FENCE.I |
| `1110011` | I-type | ECALL, EBREAK, CSRxx |

### funct3 在 R-type 和 I-type ALU 中的含义

| funct3[2:0] | R-type | I-type ALU |
|-------------|--------|------------|
| 000 | ADD / SUB | ADDI |
| 001 | SLL | SLLI |
| 010 | SLT | SLTI |
| 011 | SLTU | SLTIU |
| 100 | XOR | XORI |
| 101 | SRL / SRA | SRLI / SRAI |
| 110 | OR | ORI |
| 111 | AND | ANDI |

> ADD/SUB 由 funct7[5] 区分（0=ADD, 1=SUB），SRL/SRA 同样由 funct7[5] 区分（0=SRL, 1=SRA）。

### B-type 立即数编码（特别注意！）

B-type 的立即数看似"支离破碎"，但设计有深意：rs1、rs2、funct3、opcode 在 R/I/S/B 四种格式中位置完全一致，硬件可以**在译码阶段并行读取寄存器**而不需先判断指令类型。

```
立即数位    instr 位                         说明
imm[12]     instr[31]      符号位
imm[11]     instr[7]    
imm[10:5]   instr[30:25]
imm[4:1]    instr[11:8]
imm[0]      (隐式 0)      B-type 偏移量最低位恒为 0（16-bit 对齐）

完整 13-bit 偏移 = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
```

**手算示例**：`beq x3, x3, +8`（PC=0x04 → 目标=0x0C）

```
offset = 8 = 0b0000_0000_1000
  imm[12] = 0      → instr[31] = 0
  imm[10:5] = 0    → instr[30:25] = 000000
  imm[4:1] = 0100  → instr[11:8] = 0100  ← 常见错误：误写为 0010！
  imm[11] = 0      → instr[7] = 0
  imm[0] = (implicit 0)

机器码 = 0_000000_00011_00011_000_0100_0_1100011 = 0x00318463 ✓
错误码 = 0_000000_00011_00011_000_0010_0_1100011 = 0x00318263 ✗ (offset=4)
```

## 4. 内存访问

### 对齐要求
- **LW/SW**：地址必须 4 字节对齐（addr[1:0] == 2'b00）
- **LH/SH**：地址必须 2 字节对齐（addr[0] == 1'b0）
- **LB/SB**：无对齐要求

本项目的单周期处理器目前**不检查非对齐访问异常**（简化设计）。添加异常处理是进阶练习之一。

### 字节序
RISC-V 采用**小端字节序 (Little-Endian)**：
```
地址 0x00: 0xDE   (LSB — 最低有效字节)
地址 0x01: 0xAD
地址 0x02: 0xBE
地址 0x03: 0xEF   (MSB — 最高有效字节)

32-bit word at 0x00 = 0xEFBEADDE
```

## 5. 特权级别

RV32I 定义了三个特权级别（本项目仅使用 M-mode）：

| 级别 | 缩写 | 用途 |
|------|------|------|
| Machine (机器模式) | M-mode | 最高权限，固件/裸机程序。**本项目运行于此模式** |
| Supervisor (监管者模式) | S-mode | 操作系统内核 |
| User (用户模式) | U-mode | 应用程序 |

### 关键 CSR（控制状态寄存器，Machine 模式）

| CSR | 地址 | 说明 |
|-----|------|------|
| mstatus | 0x300 | 机器状态（全局中断使能等） |
| mtvec | 0x305 | 异常向量基址 |
| mepc | 0x341 | 异常返回地址 |
| mcause | 0x342 | 异常原因 |

> 本项目的单周期处理器暂未实现 CSR 和异常处理，列为进阶扩展目标。

## 6. 与 x86/ARM 的关键差异

| 特性 | RISC-V RV32I | x86-64 | ARMv8 AArch64 |
|------|-------------|--------|---------------|
| 指令长度 | 固定 32-bit（+ 16-bit 压缩） | 可变 1–15 字节 | 固定 32-bit |
| 条件码 | 无（比较+跳转合一） | 有 (EFLAGS) | 有 (NZCV) |
| 寻址模式 | 仅 reg+offset | 极其丰富 | reg+offset |
| 零寄存器 | x0 | 无（需 xor reg,reg） | xzr |
| 链接寄存器 | x1 (ra) | 栈上返回地址 | x30 (LR) |
| 立即数编码 | 直接提取字段 | 复杂重构 | 位模式编码 |
| 规范授权 | 开源，免专利 | Intel/AMD 专有 | ARM 授权 |
