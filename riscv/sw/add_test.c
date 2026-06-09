//------------------------------------------------------------------------------
// add_test.c — Minimal arithmetic test for RISC-V
//------------------------------------------------------------------------------
// 最简单的测试程序：执行加法并写结果到内存
//
// 编译：
//   riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -T link.ld \
//       startup.s add_test.c -o add_test.elf
//
// 提取 hex：
//   python3 ../tools/elf2hex.py add_test.elf add_test.hex
//------------------------------------------------------------------------------

#define RESULT_ADDR 0x80000000

void main() {
    volatile int *result = (volatile int*)RESULT_ADDR;

    int x = 5;
    int y = 3;

    // 基本运算
    result[0] = x + y;      // 0x80000000: 8 (ADD)
    result[1] = x - y;      // 0x80000004: 2 (SUB)
    result[2] = x & y;      // 0x80000008: 1 (AND)
    result[3] = x | y;      // 0x8000000C: 7 (OR)
    result[4] = x ^ y;      // 0x80000010: 6 (XOR)
    result[5] = x << 2;     // 0x80000014: 20 (SLL)
    result[6] = -1;         // 0x80000018: -1 (0xFFFFFFFF)

    // 有符号比较
    result[7] = (x < y) ? 1 : 0;   // 0x8000001C: 0
    result[8] = (y < x) ? 1 : 0;   // 0x80000020: 1

    // 死循环
    while (1) { }
}
