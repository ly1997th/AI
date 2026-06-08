# RISC-V RV32I 指令集速查表

> 完整 opcode 映射与指令编码参考。用于 RTL 实现时对照译码逻辑。

## opcode 映射

| opcode[6:0] | 指令类别 | 指令列表 |
|-------------|----------|----------|
| `011_0111` | **LUI** | lui |
| `001_0111` | **AUIPC** | auipc |
| `110_1111` | **JAL** | jal |
| `110_0111` | **JALR** | jalr |
| `110_0011` | **Branch** | beq, bne, blt, bge, bltu, bgeu |
| `000_0011` | **Load** | lb, lh, lw, lbu, lhu |
| `010_0011` | **Store** | sb, sh, sw |
| `001_0011` | **I-type ALU** | addi, slti, sltiu, xori, ori, andi, slli, srli, srai |
| `011_0011` | **R-type ALU** | add, sub, sll, slt, sltu, xor, srl, sra, or, and |
| `000_1111` | **FENCE** | fence, fence.i |
| `111_0011` | **ECALL/EBREAK** | ecall, ebreak, csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci |

## R-type (opcode = 011_0011)

| 指令 | funct7 | rs2 | rs1 | funct3 | rd | opcode |
|------|--------|-----|-----|--------|----|--------|
| ADD | 0000000 | rs2 | rs1 | 000 | rd | 0110011 |
| SUB | 0100000 | rs2 | rs1 | 000 | rd | 0110011 |
| SLL | 0000000 | rs2 | rs1 | 001 | rd | 0110011 |
| SLT | 0000000 | rs2 | rs1 | 010 | rd | 0110011 |
| SLTU | 0000000 | rs2 | rs1 | 011 | rd | 0110011 |
| XOR | 0000000 | rs2 | rs1 | 100 | rd | 0110011 |
| SRL | 0000000 | rs2 | rs1 | 101 | rd | 0110011 |
| SRA | 0100000 | rs2 | rs1 | 101 | rd | 0110011 |
| OR  | 0000000 | rs2 | rs1 | 110 | rd | 0110011 |
| AND | 0000000 | rs2 | rs1 | 111 | rd | 0110011 |

> **注意**：SUB 和 ADD 的 funct3 相同（000），区别在于 funct7[30]（即 funct7[5]）— ADD 为 0，SUB 为 1。

## I-type ALU (opcode = 001_0011)

| 指令 | imm[11:0] | rs1 | funct3 | rd | opcode |
|------|-----------|-----|--------|----|--------|
| ADDI | imm[11:0] | rs1 | 000 | rd | 0010011 |
| SLTI | imm[11:0] | rs1 | 010 | rd | 0010011 |
| SLTIU | imm[11:0] | rs1 | 011 | rd | 0010011 |
| XORI | imm[11:0] | rs1 | 100 | rd | 0010011 |
| ORI  | imm[11:0] | rs1 | 110 | rd | 0010011 |
| ANDI | imm[11:0] | rs1 | 111 | rd | 0010011 |
| SLLI | 0000000 + shamt[4:0] | rs1 | 001 | rd | 0010011 |
| SRLI | 0000000 + shamt[4:0] | rs1 | 101 | rd | 0010011 |
| SRAI | 0100000 + shamt[4:0] | rs1 | 101 | rd | 0010011 |

## I-type Load (opcode = 000_0011)

| 指令 | imm[11:0] | rs1 | funct3 | rd | opcode |
|------|-----------|-----|--------|----|--------|
| LB  | offset[11:0] | rs1 | 000 | rd | 0000011 |
| LH  | offset[11:0] | rs1 | 001 | rd | 0000011 |
| LW  | offset[11:0] | rs1 | 010 | rd | 0000011 |
| LBU | offset[11:0] | rs1 | 100 | rd | 0000011 |
| LHU | offset[11:0] | rs1 | 101 | rd | 0000011 |

## S-type Store (opcode = 010_0011)

| 指令 | imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode |
|------|-----------|-----|-----|--------|----------|--------|
| SB | imm[11:5] | rs2 | rs1 | 000 | imm[4:0] | 0100011 |
| SH | imm[11:5] | rs2 | rs1 | 001 | imm[4:0] | 0100011 |
| SW | imm[11:5] | rs2 | rs1 | 010 | imm[4:0] | 0100011 |

## B-type Branch (opcode = 110_0011)

| 指令 | imm[12\|10:5] | rs2 | rs1 | funct3 | imm[4:1\|11] | opcode |
|------|---------------|-----|-----|--------|--------------|--------|
| BEQ  | imm[12\|10:5] | rs2 | rs1 | 000 | imm[4:1\|11] | 1100011 |
| BNE  | imm[12\|10:5] | rs2 | rs1 | 001 | imm[4:1\|11] | 1100011 |
| BLT  | imm[12\|10:5] | rs2 | rs1 | 100 | imm[4:1\|11] | 1100011 |
| BGE  | imm[12\|10:5] | rs2 | rs1 | 101 | imm[4:1\|11] | 1100011 |
| BLTU | imm[12\|10:5] | rs2 | rs1 | 110 | imm[4:1\|11] | 1100011 |
| BGEU | imm[12\|10:5] | rs2 | rs1 | 111 | imm[4:1\|11] | 1100011 |

> B-type 立即数是：`{imm[12], imm[10:5], imm[4:1], imm[11], 1'b0}` — 隐式最低位为 0（分支目标总是偶数地址）。

## J-type JAL (opcode = 110_1111)

| 指令 | imm[20\|10:1\|11\|19:12] | rd | opcode |
|------|--------------------------|----|--------|
| JAL | imm[20\|10:1\|11\|19:12] | rd | 1101111 |

> J-type 立即数是：`{imm[20], imm[19:12], imm[11], imm[10:1], 1'b0}` — 同样隐式最低位为 0。

## I-type JALR (opcode = 110_0111)

| 指令 | imm[11:0] | rs1 | funct3 | rd | opcode |
|------|-----------|-----|--------|----|--------|
| JALR | offset[11:0] | rs1 | 000 | rd | 1100111 |

## U-type (opcode = 011_0111 LUI, 001_0111 AUIPC)

| 指令 | imm[31:12] | rd | opcode |
|------|------------|----|--------|
| LUI | imm[31:12] | rd | 0110111 |
| AUIPC | imm[31:12] | rd | 0010111 |

## 控制单元译码真值表

| 指令类型 | RegWrite | ALUSrc | MemWrite | MemRead | MemtoReg | Branch | ALUOp[1:0] |
|----------|----------|--------|----------|---------|----------|--------|------------|
| R-type | 1 | 0 | 0 | 0 | 0 | 0 | 10 |
| I-type ALU | 1 | 1 | 0 | 0 | 0 | 0 | 11 |
| Load | 1 | 1 | 0 | 1 | 1 | 0 | 00 |
| Store | 0 | 1 | 1 | 0 | X | 0 | 00 |
| Branch | 0 | 0 | 0 | 0 | X | 1 | 01 |
| JAL | 1 | X | 0 | 0 | X | X | XX |
| JALR | 1 | X | 0 | 0 | X | X | XX |
| LUI | 1 | X | 0 | 0 | X | X | XX |
| AUIPC | 1 | X | 0 | 0 | X | X | XX |
