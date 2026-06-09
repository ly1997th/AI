#!/usr/bin/env python3
#------------------------------------------------------------------------------
# elf2hex.py — Convert RISC-V ELF to Verilog $readmemh hex format
#------------------------------------------------------------------------------
# 用法：
#   python3 elf2hex.py <input.elf> [output.hex]
#
# 功能：
#   从 ELF 文件中提取 .text 和 .data 段的机器码，生成 Verilog $readmemh
#   可读取的 hex 文件。每行一个 32-bit word（8 位十六进制）。
#
# 说明：
#   - 只提取 .text 和 .data 段（其他段忽略）
#   - 按地址排序输出
#   - 地址作为注释输出（便于调试）
#   - 输出格式兼容 Verilog 的 $readmemh 系统任务
#
# 依赖：
#   pip install pyelftools
#   或
#   使用 objcopy 替代（更简单，不需要额外 Python 包）
#------------------------------------------------------------------------------

import sys
import os
import struct
import subprocess


def extract_with_objcopy(elf_path, output_path):
    """使用 riscv64-unknown-elf-objcopy 提取二进制，然后转为 hex。

    这是首选方法，因为 objcopy 随工具链自带，无需额外 Python 包。
    """
    # 交叉编译器前缀：尝试检测
    cross = "riscv64-unknown-elf-"

    # 1. objcopy 生成 binary
    bin_path = output_path.replace(".hex", ".bin")
    cmd = [f"{cross}objcopy", "-O", "binary", elf_path, bin_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"ERROR: objcopy failed: {result.stderr}")
        print("  Is riscv64-unknown-elf- toolchain installed?")
        return 1

    # 2. 读取二进制并转为 hex
    with open(bin_path, "rb") as f:
        data = f.read()

    # 按 4 字节分组（RISC-V 指令为 32-bit little-endian）
    lines = []
    addr = 0
    for i in range(0, len(data), 4):
        word_bytes = data[i:i+4]
        if len(word_bytes) < 4:
            # 补零到 4 字节
            word_bytes = word_bytes + b'\x00' * (4 - len(word_bytes))
        word = struct.unpack("<I", word_bytes)[0]
        lines.append(f"@{addr:08X} {word:08X}")
        addr += 4

    with open(output_path, "w") as f:
        f.write("// RISC-V program hex dump\n")
        f.write(f"// Source: {os.path.basename(elf_path)}\n")
        f.write("// Format: Verilog $readmemh compatible\n")
        f.write("// @<address> <data>\n\n")
        for line in lines:
            f.write(line + "\n")

    # 清理临时 bin 文件
    if os.path.exists(bin_path):
        os.remove(bin_path)

    print(f"  {elf_path} -> {output_path} ({addr} bytes, {len(lines)} words)")
    return 0


def extract_with_pyelftools(elf_path, output_path):
    """使用 pyelftools 库从 ELF 提取段数据。

    备用方法，需要安装 pyelftools: pip install pyelftools
    """
    try:
        from elftools.elf.elffile import ELFFile
    except ImportError:
        print("ERROR: pyelftools not installed.")
        print("  Install: pip install pyelftools")
        print("  Or use objcopy method (remove --use-pyelf option)")
        return 1

    with open(elf_path, "rb") as f:
        elffile = ELFFile(f)

        # 只提取可加载段
        segments = []
        for seg in elffile.iter_segments():
            if seg.header.p_type == "PT_LOAD":
                segments.append((
                    seg.header.p_vaddr,
                    seg.data()
                ))

        if not segments:
            print("WARNING: No loadable segments found in ELF")
            return 1

        # 合并所有段，按地址组织
        lines = []
        total_bytes = 0

        for vaddr, data in segments:
            for i in range(0, len(data), 4):
                word_bytes = data[i:i+4]
                if len(word_bytes) < 4:
                    word_bytes = word_bytes + b'\x00' * (4 - len(word_bytes))
                word = struct.unpack("<I", word_bytes)[0]
                word_addr = vaddr + i
                lines.append(f"@{word_addr:08X} {word:08X}")
                total_bytes += 4

        with open(output_path, "w") as f:
            f.write("// RISC-V program hex dump\n")
            f.write(f"// Source: {os.path.basename(elf_path)}\n")
            f.write("// Format: Verilog $readmemh compatible\n\n")
            for line in sorted(lines):
                f.write(line + "\n")

        print(f"  {elf_path} -> {output_path} ({total_bytes} bytes) [pyelftools]")
        return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        print("USAGE: python3 elf2hex.py <input.elf> [output.hex] [--use-pyelf]")
        print("")
        print("  --use-pyelf  Use pyelftools instead of objcopy")
        sys.exit(1)

    elf_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else elf_path.replace(".elf", ".hex")
    use_pyelf = "--use-pyelf" in sys.argv

    if not os.path.exists(elf_path):
        print(f"ERROR: File not found: {elf_path}")
        sys.exit(1)

    print(f"Extracting: {elf_path}")

    if use_pyelf:
        ret = extract_with_pyelftools(elf_path, output_path)
    else:
        ret = extract_with_objcopy(elf_path, output_path)

    if ret != 0:
        # objcopy 失败时，尝试 pyelftools 作为后备
        print("  Trying pyelftools as fallback...")
        ret = extract_with_pyelftools(elf_path, output_path)

    if ret == 0:
        print(f"  Output: {output_path}")

    sys.exit(ret)


if __name__ == "__main__":
    main()
