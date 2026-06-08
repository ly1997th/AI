#===============================================================================
# setup.sh — RISC-V CPU Development Environment Setup (Linux/Mac)
#===============================================================================
# 用法：
#   bash tools/setup.sh
#
# 此脚本检查并安装必需的开发工具。
#===============================================================================

set -e

echo "==================================="
echo "RISC-V CPU Dev Environment Setup"
echo "==================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_tool() {
    local tool=$1
    local install_hint=$2
    if command -v "$tool" &> /dev/null; then
        echo -e "  ${GREEN}[OK]${NC} $tool found: $(which $tool)"
        return 0
    else
        echo -e "  ${RED}[MISSING]${NC} $tool not found"
        echo -e "    ${YELLOW}Install: $install_hint${NC}"
        return 1
    fi
}

# Icarus Verilog
echo "Checking Icarus Verilog..."
check_tool "iverilog" "sudo apt install iverilog (Ubuntu) / brew install icarus-verilog (Mac)"

echo ""
echo "Checking vvp (Icarus runtime)..."
check_tool "vvp" "Comes with Icarus Verilog package"

# GTKWave
echo ""
echo "Checking GTKWave..."
check_tool "gtkwave" "sudo apt install gtkwave (Ubuntu) / brew install gtkwave (Mac)"

# Make
echo ""
echo "Checking Make..."
check_tool "make" "sudo apt install build-essential (Ubuntu) / xcode-select --install (Mac)"

# Python (for helper scripts)
echo ""
echo "Checking Python..."
check_tool "python3" "sudo apt install python3 (Ubuntu) / brew install python3 (Mac)"

# RISC-V GCC (optional)
echo ""
echo "Checking RISC-V GCC (optional)..."
if check_tool "riscv64-unknown-elf-gcc" "https://github.com/riscv-collab/riscv-gnu-toolchain"; then
    echo "  RISC-V GCC version: $(riscv64-unknown-elf-gcc --version | head -1)"
else
    echo "  ${YELLOW}Tip: RISC-V GCC is optional for this project."
    echo "  You can assemble test programs manually or use online tools.${NC}"
fi

# Spike (optional)
echo ""
echo "Checking Spike (optional)..."
check_tool "spike" "https://github.com/riscv-software-src/riscv-isa-sim"

# Verilator (optional)
echo ""
echo "Checking Verilator (optional)..."
check_tool "verilator" "sudo apt install verilator (Ubuntu) / brew install verilator (Mac)"

echo ""
echo "==================================="
echo "Setup complete!"
echo ""
echo "Quick start:"
echo "  cd sim && make run_tb_alu"
echo "==================================="
