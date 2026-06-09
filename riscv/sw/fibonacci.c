//------------------------------------------------------------------------------
// fibonacci.c — Fibonacci sequence calculation on RISC-V
//------------------------------------------------------------------------------
// 计算 fib(10)，结果写入 LED 地址（仿真中可观测）
//
// 编译：
//   riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -T link.ld \
//       startup.s fibonacci.c -o fibonacci.elf
//
// 提取 hex：
//   python3 ../tools/elf2hex.py fibonacci.elf fibonacci.hex
//------------------------------------------------------------------------------

#define LED_BASE 0x80000004
volatile int *leds = (volatile int*)LED_BASE;

// 计算第 n 个斐波那契数
int fib(int n) {
    if (n <= 1)
        return n;
    else
        return fib(n - 1) + fib(n - 2);
}

// 迭代版斐波那契（对 RV32I 更友好，无递归栈开销）
int fib_iter(int n) {
    int a = 0;
    int b = 1;
    for (int i = 0; i < n; i++) {
        int tmp = a + b;
        a = b;
        b = tmp;
    }
    return a;
}

void main() {
    // fib(10) = 55
    int result = fib_iter(10);
    *leds = result;  // LED should show 55 (0x37)

    // 死循环
    while (1) { }
}
