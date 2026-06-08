# RISC-V 测试程序：斐波那契数列
# 计算 fib(10)，结果保存在 x10 (a0) 中
#
# C 等效代码：
#   int a = 0, b = 1;
#   for (int i = 0; i < 10; i++) {
#       int tmp = a + b;
#       a = b;
#       b = tmp;
#   }
#   return a;

    .section .text
    .globl _start

_start:
    addi x5, x0, 0       # a = 0
    addi x6, x0, 1       # b = 1
    addi x7, x0, 10      # count = 10
    addi x8, x0, 0       # i = 0

fib_loop:
    beq  x8, x7, fib_done # if i == 10, exit loop
    add  x9, x5, x6       # tmp = a + b
    addi x5, x6, 0        # a = b
    addi x6, x9, 0        # b = tmp
    addi x8, x8, 1        # i++
    jal  x0, fib_loop     # goto fib_loop

fib_done:
    addi x10, x5, 0       # return a (fib(10) = 55)

    # 终止程序（无限循环）
done:
    beq  x0, x0, done
