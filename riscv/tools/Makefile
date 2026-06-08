#===============================================================================
# Makefile — RISC-V Processor Simulation
#===============================================================================
# 用法：
#   make               — 编译所有模块
#   make run_tb_alu    — 运行 ALU 测试
#   make run_tb_regfile — 运行寄存器文件测试
#   make run_tb_core   — 运行处理器核心测试
#   make wave_tb_alu   — 查看 ALU 波形
#   make wave_tb_core  — 查看核心波形
#   make clean         — 清理仿真产物
#   make help          — 显示帮助
#===============================================================================

# 仿真器设置
IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

# RTL 源文件
RTL_CORE = ../rtl/core/pc.v \
           ../rtl/core/regfile.v \
           ../rtl/core/alu.v \
           ../rtl/core/imm_gen.v \
           ../rtl/core/control_unit.v \
           ../rtl/core/core.v

RTL_SOC = ../rtl/soc/memory.v \
          ../rtl/soc/soc_top.v

RTL_ALL = $(RTL_CORE) $(RTL_SOC)

# Testbench
TB_DIR   = tb
TB_ALU   = $(TB_DIR)/tb_alu.v
TB_REGFILE = $(TB_DIR)/tb_regfile.v
TB_CORE  = $(TB_DIR)/tb_core.v

# Verilog 编译选项
IVFLAGS = -g2012 -Wall -DSIMULATION

#-------------------------------------------------------------------------------
# 默认目标
#-------------------------------------------------------------------------------
.PHONY: all
all: compile_tb_alu compile_tb_regfile compile_tb_core

#-------------------------------------------------------------------------------
# 帮助
#-------------------------------------------------------------------------------
.PHONY: help
help:
	@echo "RISC-V Processor Simulation Makefile"
	@echo "===================================="
	@echo "all              — 编译所有 testbench"
	@echo "run_tb_alu       — 运行 ALU 单元测试"
	@echo "run_tb_regfile   — 运行寄存器文件测试"
	@echo "run_tb_core      — 运行处理器核心测试"
	@echo "wave_tb_alu      — 查看 ALU 仿真波形"
	@echo "wave_tb_regfile  — 查看寄存器文件波形"
	@echo "wave_tb_core     — 查看核心仿真波形"
	@echo "clean            — 删除仿真产物"
	@echo "help             — 显示此帮助"

#-------------------------------------------------------------------------------
# 编译规则
#-------------------------------------------------------------------------------
%.vvp: %.v $(RTL_CORE)
	$(IVERILOG) $(IVFLAGS) -o $@ $(filter-out $<,$(RTL_CORE)) $<

compile_tb_alu: $(TB_DIR)/tb_alu.vvp
$(TB_DIR)/tb_alu.vvp: $(TB_ALU) $(RTL_CORE)
	$(IVERILOG) $(IVFLAGS) -o $@ ../rtl/core/alu.v $(TB_ALU)

compile_tb_regfile: $(TB_DIR)/tb_regfile.vvp
$(TB_DIR)/tb_regfile.vvp: $(TB_REGFILE) $(RTL_CORE)
	$(IVERILOG) $(IVFLAGS) -o $@ ../rtl/core/regfile.v $(TB_REGFILE)

compile_tb_core: $(TB_DIR)/tb_core.vvp
$(TB_DIR)/tb_core.vvp: $(TB_CORE) $(RTL_ALL)
	$(IVERILOG) $(IVFLAGS) -o $@ $(RTL_ALL) $(TB_CORE)

#-------------------------------------------------------------------------------
# 运行规则
#-------------------------------------------------------------------------------
.PHONY: run_tb_alu
run_tb_alu: $(TB_DIR)/tb_alu.vvp
	$(VVP) $(TB_DIR)/tb_alu.vvp

.PHONY: run_tb_regfile
run_tb_regfile: $(TB_DIR)/tb_regfile.vvp
	$(VVP) $(TB_DIR)/tb_regfile.vvp

.PHONY: run_tb_core
run_tb_core: $(TB_DIR)/tb_core.vvp
	$(VVP) $(TB_DIR)/tb_core.vvp

#-------------------------------------------------------------------------------
# 波形查看
#-------------------------------------------------------------------------------
.PHONY: wave_tb_alu
wave_tb_alu: tb_alu.vcd
	$(GTKWAVE) tb_alu.vcd &

.PHONY: wave_tb_regfile
wave_tb_regfile: tb_regfile.vcd
	$(GTKWAVE) tb_regfile.vcd &

.PHONY: wave_tb_core
wave_tb_core: tb_core.vcd
	$(GTKWAVE) tb_core.vcd &

#-------------------------------------------------------------------------------
# 清理
#-------------------------------------------------------------------------------
.PHONY: clean
clean:
	rm -f $(TB_DIR)/*.vvp
	rm -f *.vcd
	rm -f *.vvp
	rm -f *.out
	rm -f *.lxt *.lxt2 *.fst
