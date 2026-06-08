# RISC-V 测试程序：简单加法
# 计算 5 + 3，结果保存在 x10 (a0) 中

    .section .text
    .globl _start

_start:
    addi x1, x0, 5       # x1 = 5
    addi x2, x0, 3       # x2 = 3
    add  x10, x1, x2     # x10 = x1 + x2 = 8  (a0 = 返回值)

    # 终止程序（无限循环）
loop:
    beq  x0, x0, loop    # 自旋等待
