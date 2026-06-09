#===============================================================================
# sw/Makefile — RISC-V Bare-Metal C Program Build System
#===============================================================================
# 用法：
#   make              — 编译所有 C 程序
#   make hello        — 只编译 hello
#   make fibonacci    — 只编译 fibonacci
#   make add_test     — 只编译 add_test
#   make dis          — 反汇编所有 .elf
#   make hex          — 提取所有 hex
#   make clean        — 清理产物
#
# 前提：
#   - RISC-V GCC 工具链 (riscv64-unknown-elf-gcc)
#   - Python 3 (用于 elf2hex.py)
#===============================================================================

# 工具链
CROSS_COMPILE = riscv64-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump
READELF = $(CROSS_COMPILE)readelf

# RISC-V 选项
ARCH    = rv32i
ABI     = ilp32

# 编译选项
CFLAGS  = -march=$(ARCH) -mabi=$(ABI) -nostdlib -nostartfiles
CFLAGS += -ffreestanding -fno-builtin
CFLAGS += -Wall -Wextra -O0 -g
CFLAGS += -T link.ld

# 链接对象
LINK_OBJS = startup.s

# 源程序
PROGRAMS = hello fibonacci add_test

#===============================================================================
# 默认目标
#===============================================================================
.PHONY: all
all: $(PROGRAMS) dis hex

#===============================================================================
# 帮助
#===============================================================================
.PHONY: help
help:
	@echo "RISC-V C Program Build System"
	@echo "=============================="
	@echo "make                — 编译所有程序 + 反汇编 + 提取 hex"
	@echo "make hello          — 编译 hello"
	@echo "make fibonacci      — 编译 fibonacci"
	@echo "make add_test       — 编译 add_test"
	@echo "make dis            — 反汇编所有 .elf 文件"
	@echo "make hex            — 提取所有 hex 文件"
	@echo "make readelf        — 查看 ELF 段信息"
	@echo "make clean          — 删除所有产物"
	@echo "make help           — 显示此帮助"
	@echo ""
	@echo "需要的工具："
	@echo "  riscv64-unknown-elf-gcc    (RISC-V GCC 交叉编译)"
	@echo "  python3                    (ELF → hex 转换)"

#===============================================================================
# 编译规则
#===============================================================================
.PHONY: hello
hello: hello.elf hello.dis hello.hex

hello.elf: hello.c startup.s link.ld
	$(CC) $(CFLAGS) $(LINK_OBJS) hello.c -o $@

.PHONY: fibonacci
fibonacci: fibonacci.elf fibonacci.dis fibonacci.hex

fibonacci.elf: fibonacci.c startup.s link.ld
	$(CC) $(CFLAGS) $(LINK_OBJS) fibonacci.c -o $@

.PHONY: add_test
add_test: add_test.elf add_test.dis add_test.hex

add_test.elf: add_test.c startup.s link.ld
	$(CC) $(CFLAGS) $(LINK_OBJS) add_test.c -o $@

#===============================================================================
# 反汇编
#===============================================================================
.PHONY: dis
dis: $(addsuffix .dis,$(PROGRAMS))

%.dis: %.elf
	$(OBJDUMP) -d -M numeric $< > $@
	@echo "  Disassembly: $@"

#===============================================================================
# 提取 hex（用于 Verilog 仿真存储器初始化）
#===============================================================================
.PHONY: hex
hex: $(addsuffix .hex,$(PROGRAMS))

%.hex: %.elf
	python3 ../tools/elf2hex.py $< $@
	@echo "  Hex: $@"

#===============================================================================
# ELF 信息查看
#===============================================================================
.PHONY: readelf
readelf:
	@for prog in $(PROGRAMS); do \
		if [ -f "$$prog.elf" ]; then \
			echo ""; \
			echo "======== $$prog.elf ========"; \
			$(READELF) -S "$$prog.elf"; \
		fi; \
	done

#===============================================================================
# 清理
#===============================================================================
.PHONY: clean
clean:
	rm -f *.elf
	rm -f *.dis
	rm -f *.hex
	rm -f *.bin
	rm -f *.map
