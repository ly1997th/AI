//------------------------------------------------------------------------------
// hello.c — Simple RISC-V bare-metal test program
//------------------------------------------------------------------------------
// 功能：
//   最简单的 RISC-V 裸机程序，验证工具链和仿真环境。
//   在仿真环境中，程序运行到 _exit 后停止。
//
// 编译：
//   riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -T link.ld \
//       startup.s hello.c -o hello.elf
//
// 提取 hex：
//   python3 ../tools/elf2hex.py hello.elf hello.hex
//------------------------------------------------------------------------------

// 内存映射 I/O 地址（仿真用）
#define UART_BASE 0x80000000
#define LED_BASE  0x80000004

volatile int *uart_tx = (volatile int*)UART_BASE;
volatile int *leds    = (volatile int*)LED_BASE;

// 简单字符串输出（向 UART 写字符）
void uart_putchar(char c) {
    *uart_tx = (int)c;
}

void uart_puts(const char *s) {
    while (*s) {
        uart_putchar(*s++);
    }
}

// 入口函数（由 startup.s 调用）
void main() {
    int a = 5;
    int b = 3;
    int c = a + b;

    uart_puts("Hello RISC-V!\n");

    // 将计算结果输出到 LED（仿真中可见）
    *leds = c;  // should be 8

    // 死循环 — 仿真终止点
    while (1) { }
}
