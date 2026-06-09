# 阶段一：RISC-V ISA 基础

## 1. 什么是 ISA？

**ISA (Instruction Set Architecture，指令集架构)** 是软件与硬件之间的接口契约。它定义了：
- 处理器支持的指令集合
- 寄存器模型（数量、宽度、用途）
- 数据类型，编址方式
- 特权级别与异常处理机制

ISA 不规定硬件如何实现这些功能——这就是为什么同样的 RISC-V 程序可以运行在简单的单周期处理器上，也可以运行在复杂的超标量乱序处理器上。

## 2. RISC-V 设计哲学

### "RISC" 的精髓
- **指令少而精**：RV32I 仅有 40 条指令，但足以运行完整的操作系统
- **固定指令长度**：基础指令均为 32 位，简化硬件译码
- **Load-Store 架构**：只有 load/store 指令访问内存，运算指令只操作寄存器
- **大量寄存器**：32 个通用寄存器，减少内存访问

### RISC-V 的独特之处
- **模块化**：基础整数指令集（I）是强制要求的，其他扩展（M/A/F/D/C）按需添加
- **开源免费**：无专利限制，任何人都可以设计、实现、销售 RISC-V 处理器
- **为扩展预留空间**：opcode 编码中预留了大量自定义空间

### RISC-V 扩展字母表
| 字母 | 名称 | 说明 |
|------|------|------|
| I | 基础整数（Base Integer） | **必须实现** |
| M | 整数乘除法 | mul, div, rem 等 |
| A | 原子操作 | 多核同步所需 |
| F | 单精度浮点 | 32-bit float |
| D | 双精度浮点 | 64-bit double |
| C | 压缩指令 | 16 位短指令 |
| Privileged | 特权架构 | 机器/监管者/用户模式 |

我们学习的基础配置是 **RV32I**：32 位地址空间 + 基础整数指令集。

## 3. 寄存器文件

RISC-V 有 32 个通用寄存器（x0–x31），每个 32 位宽（RV32）。

| 寄存器 | ABI 名称 | 用途 | 说明 |
|--------|----------|------|------|
| x0 | zero | 恒为零 | 写入被忽略，读出始终为 0 |
| x1 | ra | 返回地址（Return Address） | jal 指令自动保存 |
| x2 | sp | 栈指针（Stack Pointer） | 指向栈顶 |
| x3 | gp | 全局指针（Global Pointer） | 指向全局数据区 |
| x4 | tp | 线程指针（Thread Pointer） | 线程局部存储 |
| x5–x7 | t0–t2 | 临时寄存器 | 函数调用不保存 |
| x8 | s0/fp | 保存寄存器 / 帧指针 | 函数调用保存 |
| x9 | s1 | 保存寄存器 | 函数调用保存 |
| x10–x11 | a0–a1 | 函数参数 / 返回值 | |
| x12–x17 | a2–a7 | 函数参数 | |
| x18–x27 | s2–s11 | 保存寄存器 | 函数调用保存 |
| x28–x31 | t3–t6 | 临时寄存器 | 函数调用不保存 |

### 关键约定
- **Caller-saved** (t0–t6, a0–a7, ra)：调用者负责保存。子函数可以随意修改这些寄存器。
- **Callee-saved** (s0–s11, sp, gp, tp)：被调用者负责保存。子函数如需使用，必须先保存原值，返回前恢复。
- **x0 (zero)** 是硬件实现的零寄存器——这简化了很多指令的实现（不需要单独 `nop` 指令，`addi x0, x0, 0` 就是 nop）。

## 4. 指令格式（六种）

RISC-V 基础指令固定 32 位。指令的低 7 位固定为 opcode，高位的布局由 opcode 决定。

```
R-type:  funct7    rs2    rs1    funct3   rd     opcode
         7 bits   5 bits  5 bits  3 bits  5 bits  7 bits

I-type:  imm[11:0]        rs1    funct3   rd     opcode
         12 bits          5 bits  3 bits  5 bits  7 bits

S-type:  imm[11:5]  rs2    rs1    funct3  imm[4:0]  opcode
         7 bits    5 bits  5 bits  3 bits  5 bits    7 bits

B-type:  imm[12|10:5]  rs2  rs1  funct3  imm[4:1|11]  opcode
         7 bits       5bits 5bits 3 bits  5 bits       7 bits

U-type:  imm[31:12]              rd     opcode
         20 bits                5 bits  7 bits

J-type:  imm[20|10:1|11|19:12]   rd     opcode
         20 bits                5 bits  7 bits
```

### 为什么 B-type 立即数位这么"碎"？
B-type 的立即数位故意不连续是为了简化硬件：所有指令格式中，rs1/rs2/rd 字段都在固定位置（第 15–19、20–24、7–11 位），硬件可以在译码阶段并行读取寄存器而无需关心指令类型。

### opcode 速览
| opcode[6:0] | 指令类型 |
|------------|----------|
| 0110011 | R-type（寄存器-寄存器运算） |
| 0010011 | I-type（立即数运算） |
| 0000011 | I-type（Load） |
| 0100011 | S-type（Store） |
| 1100011 | B-type（分支） |
| 0110111 | U-type（LUI） |
| 0010111 | U-type（AUIPC） |
| 1101111 | J-type（JAL） |
| 1100111 | I-type（JALR） |

## 5. RV32I 指令分类

### 算术运算指令
| 指令 | 格式 | 功能 |
|------|------|------|
| ADD rd, rs1, rs2 | R | rd = rs1 + rs2 |
| SUB rd, rs1, rs2 | R | rd = rs1 - rs2 |
| ADDI rd, rs1, imm | I | rd = rs1 + imm (符号扩展) |
| LUI rd, imm | U | rd = imm << 12 |
| AUIPC rd, imm | U | rd = PC + (imm << 12) |
| SLT rd, rs1, rs2 | R | rd = (rs1 < rs2) ? 1 : 0 (有符号) |
| SLTI rd, rs1, imm | I | rd = (rs1 < imm) ? 1 : 0 (有符号) |
| SLTU rd, rs1, rs2 | R | rd = (rs1 < rs2) ? 1 : 0 (无符号) |
| SLTIU rd, rs1, imm | I | rd = (rs1 < imm) ? 1 : 0 (无符号) |

### 逻辑运算指令
| 指令 | 功能 |
|------|------|
| XOR rd, rs1, rs2 | rd = rs1 ^ rs2 |
| OR rd, rs1, rs2 | rd = rs1 \| rs2 |
| AND rd, rs1, rs2 | rd = rs1 & rs2 |
| XORI/ORI/ANDI rd, rs1, imm | 立即数版本 |
| SLL rd, rs1, rs2 | rd = rs1 << rs2[4:0] (逻辑左移) |
| SRL rd, rs1, rs2 | rd = rs1 >> rs2[4:0] (逻辑右移) |
| SRA rd, rs1, rs2 | rd = rs1 >> rs2[4:0] (算术右移) |
| SLLI/SRLI/SRAI rd, rs1, shamt | 立即数移位 |

### Load/Store 指令
| 指令 | 功能 |
|------|------|
| LW rd, offset(rs1) | rd = mem[rs1 + offset] (32-bit) |
| LH rd, offset(rs1) | rd = sign_ext(mem[rs1 + offset], 16-bit) |
| LHU rd, offset(rs1) | rd = zero_ext(mem[rs1 + offset], 16-bit) |
| LB rd, offset(rs1) | rd = sign_ext(mem[rs1 + offset], 8-bit) |
| LBU rd, offset(rs1) | rd = zero_ext(mem[rs1 + offset], 8-bit) |
| SW rs2, offset(rs1) | mem[rs1 + offset] = rs2 (32-bit) |
| SH rs2, offset(rs1) | mem[rs1 + offset] = rs2 (16-bit) |
| SB rs2, offset(rs1) | mem[rs1 + offset] = rs2 (8-bit) |

### 分支指令
| 指令 | 功能 |
|------|------|
| BEQ rs1, rs2, offset | if rs1 == rs2, PC += offset |
| BNE rs1, rs2, offset | if rs1 != rs2, PC += offset |
| BLT rs1, rs2, offset | if rs1 < rs2 (有符号), PC += offset |
| BGE rs1, rs2, offset | if rs1 >= rs2 (有符号), PC += offset |
| BLTU rs1, rs2, offset | if rs1 < rs2 (无符号), PC += offset |
| BGEU rs1, rs2, offset | if rs1 >= rs2 (无符号), PC += offset |

### 跳转指令
| 指令 | 功能 |
|------|------|
| JAL rd, offset | rd = PC+4; PC += offset |
| JALR rd, rs1, offset | rd = PC+4; PC = rs1 + offset |

### 系统指令
| 指令 | 格式 | 功能 |
|------|------|------|
| ECALL | I | 环境调用（系统调用），触发异常切换到更高特权级 |
| EBREAK | I | 断点异常，用于调试器 |
| FENCE | I | 内存访问顺序保证（多核/IO 同步） |
| FENCE.I | I | 指令缓存同步 |
| CSRRW/CSRRS/CSRRC | I | CSR 读写操作（本项目暂不实现） |

> 本项目当前实现**不包括** ECALL/EBREAK/CSR 指令（这些需要异常处理机制）。 `FENCE` 和 `FENCE.I` 在单核简单系统中可视为 NOP。

## 6. 机器码手工汇编练习

> **本节至关重要**：testbench 中发现的 bug 正是源自 B-type 立即数编码的计算错误。动手算一遍就不会再犯同样的错误。

### 练习 1：ADDI
```
addi x5, x0, 99
  I-type: opcode=0010011, funct3=000
  rd=x5=00101, rs1=x0=00000
  imm=99=0x063=000001100011

  编码: imm[11:0]=000001100011, rs1=00000, funct3=000, rd=00101, opcode=0010011
  = 0000_0110_0011_0000_0000_0010_1001_0011
  = 0x06300293 ✓
```

### 练习 2：ADD
```
add x3, x1, x2
  R-type: opcode=0110011, funct3=000, funct7=0000000
  rd=x3=00011, rs1=x1=00001, rs2=x2=00010

  编码: funct7=0000000, rs2=00010, rs1=00001, funct3=000, rd=00011, opcode=0110011
  = 0000000_00010_00001_000_00011_0110011
  = 0x002081B3 ✓
```

### 练习 3：BEQ（**重点！B-type 立即数易错**）
```
beq x3, x3, +8      # PC=0x04, 目标=PC+8=0x0C（跳过 2 条指令）
  B-type: opcode=1100011, funct3=000 (BEQ)
  rs1=x3=00011, rs2=x3=00011
  offset=8 bytes = 0b0000_0000_1000

B-type 立即数位映射（offset 隐式最低位恒为 0）：
  imm[12]=0      → instr[31]=0
  imm[11]=0      → instr[7]=0
  imm[10:5]=0    → instr[30:25]=000000
  imm[4:1]=4     → instr[11:8]=0100   ← 关键！offset=8 → imm[4:1]=4, 不是 2!
  imm[0]=(隐式0)

  编码: 0_000000_00011_00011_000_0100_0_1100011
  = 0x00318463 ✓

  常见错误: 0x00318263 (imm[4:1]=2, offset=4) → 只跳 1 条指令！
```

### 练习 4：JAL
```
jal ra, +12         # PC=0x00, 目标=0x0C, 保存返回地址到 ra(x1)
  J-type: opcode=1101111
  rd=x1=00001
  offset=12 = 0b0000_0000_1100

J-type 立即数位映射：
  imm[20]=0     → instr[31]=0
  imm[19:12]=0  → instr[19:12]=00000000
  imm[11]=0     → instr[20]=0
  imm[10:1]=6   → instr[30:21]=0000000110  (12>>1=6)
  imm[0]=(隐式0)

  编码: 0_0000000110_0_00000000_00001_1101111
  = 0x00C000EF ✓
```

### 手工汇编快速自检表

| 错误 | 症状 | 纠正 |
|------|------|------|
| B-type 忘了隐式 LSB=0 | offset 减半 | `imm[4:1] = offset[5:2]`，不是 `offset[3:0]` |
| J-type 忘了隐式 LSB=0 | 跳转距离减半 | `imm[10:1] = offset[11:1]` |
| S-type 拼接顺序错 | 地址计算错误 | `{imm[11:5], imm[4:0]} = offset[11:0]` |
| U-type 忘记左移 12 | 立即数错误 | `imm[31:12] << 12` |

## 7. 汇编语言示例

```asm
# 简单的加法
addi t0, zero, 5      # t0 = 0 + 5 = 5
addi t1, zero, 3      # t1 = 0 + 3 = 3
add  t2, t0, t1       # t2 = t0 + t1 = 8

# 循环计算 1+2+...+10
addi t0, zero, 0      # sum = 0
addi t1, zero, 1      # i = 1
addi t2, zero, 10     # limit = 10
loop:
    add  t0, t0, t1   # sum += i
    addi t1, t1, 1    # i++
    blt  t1, t2, loop # if i < 10, goto loop（i=10 时退出）

    # 注意：RV32I 没有 "ble" 指令！
    # ble rs1, rs2 是伪指令，等价于 bge rs2, rs1
    # 本项目暂不实现伪指令，始终使用真实 RISC-V 指令

# 函数调用
jal  ra, my_func      # 跳转到 my_func，保存返回地址到 ra
# ... 函数返回时用 jalr zero, ra, 0
```

## 8. 下一步

完成本章学习后：
1. 熟记六种指令格式的位布局（对照 [refs/instructions-reference.md](../refs/instructions-reference.md)）
2. **亲手算 3-5 条指令的机器码**（特别是 B-type，最容易出错！见 [refs/riscv-spec-summary.md](../refs/riscv-spec-summary.md) 第3节）
3. 能看懂简单的 RISC-V 汇编代码，打开 [sw/](../sw/) 观察 C→汇编 的编译结果
4. 进入 [阶段二：数字逻辑与硬件思维](02-digital-logic.md)
