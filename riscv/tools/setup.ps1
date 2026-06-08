#===============================================================================
# setup.ps1 — RISC-V CPU Development Environment Setup (Windows)
#===============================================================================
# 用法：
#   .\tools\setup.ps1
#
# 此脚本检查并安装必需的开发工具（Windows 环境）。
#===============================================================================

Write-Host "===================================" -ForegroundColor Cyan
Write-Host "RISC-V CPU Dev Environment Setup" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

function Check-Tool {
    param($Name, $TestCommand, $InstallHint)

    Write-Host -NoNewline "  Checking $Name... "
    try {
        $result = Invoke-Expression $TestCommand 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK]" -ForegroundColor Green
            return $true
        }
    } catch {
        # command not found
    }
    Write-Host "[MISSING]" -ForegroundColor Red
    Write-Host "    Install: $InstallHint" -ForegroundColor Yellow
    return $false
}

# Check winget (Windows Package Manager)
Check-Tool "winget" "winget --version" "Install from Microsoft Store or https://github.com/microsoft/winget-cli"

Write-Host ""

# Icarus Verilog
Write-Host "Checking Icarus Verilog..."
$hasIverilog = Check-Tool "iverilog" "iverilog -V" "winget install iverilog"
if (-not $hasIverilog) {
    Write-Host "    Alternative: Download from https://bleyer.org/icarus/" -ForegroundColor Gray
}

Write-Host ""

# GTKWave
Write-Host "Checking GTKWave..."
$hasGtkwave = Check-Tool "gtkwave" "gtkwave --version" "winget install gtkwave"
if (-not $hasGtkwave) {
    Write-Host "    Alternative: Download from https://gtkwave.sourceforge.net/" -ForegroundColor Gray
}

Write-Host ""

# Make (via Chocolatey or GnuWin32)
Write-Host "Checking Make..."
Check-Tool "make" "make --version" "winget install GnuWin32.Make OR install via Chocolatey: choco install make"

Write-Host ""

# Git Bash (useful for Makefile on Windows)
Write-Host "Checking Git Bash..."
$hasGitBash = Check-Tool "bash" "bash --version" "winget install Git.Git"

if ($hasGitBash) {
    Write-Host "    Tip: Use Git Bash to run the Makefile (cd sim && make run_tb_alu)" -ForegroundColor Gray
}

Write-Host ""

# RISC-V GCC (optional)
Write-Host "Checking RISC-V GCC (optional)..."
Check-Tool "riscv64-unknown-elf-gcc" "riscv64-unknown-elf-gcc --version" "https://github.com/riscv-collab/riscv-gnu-toolchain"

Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Setup complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Quick start:" -ForegroundColor Green
Write-Host "  cd sim && make run_tb_alu" -ForegroundColor White
Write-Host "===================================" -ForegroundColor Cyan
