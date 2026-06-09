#------------------------------------------------------------------------------
# startup.s — Bare-metal RISC-V startup code (CRT0)
#------------------------------------------------------------------------------
# 功能：
#   1. 设置栈指针 (sp)
#   2. 清零 .bss 段
#   3. 调用 main() 函数
#   4. main 返回后进入死循环
#
# 这是 RISC-V 裸机程序的最小启动代码。替代标准 C 库的 crt0.o。
# 链接脚本 (link.ld) 定义了 _stack_top, _bss_start, _bss_end 等符号。
#
# 用法：
#   将此文件与 C 程序一起编译链接
#   riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib \
#       -T link.ld startup.s main.c -o program.elf
#------------------------------------------------------------------------------

    .section .text
    .globl _start
    .type _start, @function

_start:
    # 设置栈指针（链接脚本中定义 _stack_top）
    la   sp, _stack_top

    # 清零 .bss 段
    la   t0, _bss_start
    la   t1, _bss_end
1:
    bge  t0, t1, 2f       # if t0 >= t1, 跳过量零循环
    sw   zero, 0(t0)      # *t0 = 0
    addi t0, t0, 4        # t0 += 4
    j    1b               # goto 1
2:

    # 跳转到 C 语言的 main() 函数
    call main

    # main 返回后的处理（死循环）
_exit:
    j    _exit
