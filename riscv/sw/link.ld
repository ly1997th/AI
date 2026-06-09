/*----------------------------------------------------------------------------
 * link.ld — Linker script for bare-metal RISC-V RV32I programs
 *----------------------------------------------------------------------------
 * 内存布局（适用于仿真环境）：
 *   0x00000000 — 程序入口（.text 段）
 *   0x00001000 — 只读数据（.rodata 段）
 *   0x00002000 — 已初始化数据（.data 段）
 *   0x00003000 — 未初始化数据（.bss 段）
 *   0x00004000 — 栈顶（向下生长）
 *
 * 注意：仿真用存储器从地址 0 开始，这些地址对应 memory.v 中的 word 地址。
 *----------------------------------------------------------------------------*/

MEMORY {
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS {
    /* 代码段：从地址 0 开始 */
    .text : {
        *(.text.init)     /* 启动代码 */
        *(.text)
        *(.text.*)
    } > ram

    /* 只读数据段 */
    .rodata : ALIGN(4) {
        *(.rodata)
        *(.rodata.*)
    } > ram

    /* 已初始化数据段 */
    .data : ALIGN(4) {
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
    } > ram

    /* BSS 段（未初始化数据） */
    .bss : ALIGN(4) {
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        . = ALIGN(4);
        _bss_end = .;
    } > ram

    /* 栈：从 0x4000 向下生长 */
    .stack (NOLOAD) : ALIGN(16) {
        . = . + 1024;       /* 1KB 栈空间 */
        . = ALIGN(16);
        _stack_top = .;
    } > ram

    /* 丢弃不需要的标准库段 */
    /DISCARD/ : {
        *(.comment)
        *(.note.*)
        *(.eh_frame)
        *(.debug_*)
    }
}
