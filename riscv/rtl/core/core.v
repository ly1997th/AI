//------------------------------------------------------------------------------
// core.v — Processor Core Datapath (处理器核心数据通路)
//------------------------------------------------------------------------------
// 功能：
//   集成所有核心模块，构成完整的单周期 RISC-V RV32I 数据通路
//
// 子模块：
//   pc           — 程序计数器
//   regfile      — 寄存器文件 (32×32)
//   alu          — 算术逻辑单元
//   imm_gen      — 立即数生成器
//   control_unit — 控制单元（主译码 + ALU 控制）
//
// 数据通路信号：
//   PC → 指令存储器取指令 → 译码 → 寄存器读 → ALU → 数据存储器读写 → 写回寄存器
//
// 接口：
//   clk, rst_n        — 时钟与复位
//   instr_i[31:0]     — 指令输入（来自指令存储器）
//   mem_rdata_i[31:0] — 内存读数据（来自数据存储器）
//   pc_o[31:0]        — PC 输出（到存储器地址）
//   mem_addr_o[31:0]  — 数据存储器地址
//   mem_wdata_o[31:0] — 数据存储器写数据
//   mem_write_o       — 数据存储器写使能
//   mem_read_o        — 数据存储器读使能
//
// 设计要点：
//   - 这是纯组合数据通路 + 时钟触发的 PC 和寄存器文件
//   - PC 更新逻辑需要考虑四种情况：顺序执行 / 分支 / JAL / JALR
//   - 写回数据选择：MemtoReg ? 内存数据 : ALU 结果
//   - ALU 第二操作数选择：ALUSrc ? 立即数 : rs2
//------------------------------------------------------------------------------

module core (
    input  wire        clk,
    input  wire        rst_n,

    // 指令存储器接口
    input  wire [31:0] instr_i,        // 取到的指令
    output wire [31:0] pc_o,           // 指令地址

    // 数据存储器接口
    output wire [31:0] mem_addr_o,     // 数据存储地址
    output wire [31:0] mem_wdata_o,    // 写数据
    input  wire [31:0] mem_rdata_i,    // 读数据
    output wire        mem_write_o,    // 写使能
    output wire        mem_read_o      // 读使能
);

    //--------------------------------------------------------------------------
    // 内部信号声明
    //--------------------------------------------------------------------------

    // PC 相关
    wire [31:0] pc, next_pc, pc_plus_4;
    wire [31:0] branch_target, jal_target, jalr_target;
    wire        branch_taken;

    // 指令字段（从 instr_i 中提取）
    wire [6:0]  opcode;
    wire [4:0]  rs1_addr, rs2_addr, rd_addr;
    wire [2:0]  funct3;
    wire [6:0]  funct7;
    wire        funct7_5;

    // 寄存器文件
    wire [31:0] rd1, rd2, wd3;

    // 立即数
    wire [31:0] imm;

    // 控制信号
    wire        reg_write, alu_src, mem_write, mem_read, mem_to_reg;
    wire        branch, jump, jump_reg;
    wire [1:0]  alu_op;
    wire [3:0]  alu_control;

    // ALU
    wire [31:0] alu_a, alu_b, alu_result;
    wire        alu_zero;

    //--------------------------------------------------------------------------
    // 子模块实例化
    //--------------------------------------------------------------------------

    // 程序计数器
    pc u_pc (
        .clk    (clk),
        .rst_n  (rst_n),
        .next_pc(next_pc),
        .pc     (pc)
    );

    // 寄存器文件
    regfile u_regfile (
        .clk  (clk),
        .rst_n(rst_n),
        .a1   (rs1_addr),
        .rd1  (rd1),
        .a2   (rs2_addr),
        .rd2  (rd2),
        .a3   (rd_addr),
        .we3  (reg_write),
        .wd3  (wd3)
    );

    // ALU
    alu u_alu (
        .a          (alu_a),
        .b          (alu_b),
        .alu_control(alu_control),
        .result     (alu_result),
        .zero       (alu_zero)
    );

    // 立即数生成器
    imm_gen u_imm_gen (
        .instr(instr_i),
        .imm  (imm)
    );

    // 控制单元
    control_unit u_control (
        .opcode     (opcode),
        .reg_write  (reg_write),
        .alu_src    (alu_src),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .mem_to_reg (mem_to_reg),
        .branch     (branch),
        .jump       (jump),
        .jump_reg   (jump_reg),
        .alu_op     (alu_op),
        .funct3     (funct3),
        .funct7_5   (funct7_5),
        .alu_control(alu_control)
    );

    //--------------------------------------------------------------------------
    // 指令字段提取（组合逻辑）
    //--------------------------------------------------------------------------
    assign opcode   = instr_i[6:0];
    assign rd_addr  = instr_i[11:7];
    assign funct3   = instr_i[14:12];
    assign rs1_addr = instr_i[19:15];
    assign rs2_addr = instr_i[24:20];
    assign funct7   = instr_i[31:25];
    assign funct7_5 = instr_i[30];   // funct7[5]，用于区分 ADD/SUB 和 SRL/SRA

    //--------------------------------------------------------------------------
    // TODO: 数据通路连接
    //--------------------------------------------------------------------------

    // ALU 操作数选择
    // alu_a = rd1
    // alu_b = (alu_src) ? imm : rd2

    // 写回数据选择
    // wd3 = (mem_to_reg) ? mem_rdata_i : alu_result

    //--------------------------------------------------------------------------
    // TODO: PC 更新逻辑
    //--------------------------------------------------------------------------

    // pc_plus_4 = pc + 4
    // branch_target = pc + imm    (B-type 立即数已经是偏移量)
    // jal_target = pc + imm       (J-type)
    // jalr_target = (rd1 + imm) & ~32'h1  (最低位清零，对齐)

    // 分支跳转判断：
    //   case (funct3)
    //       3'b000: branch_taken = (alu_zero);             // BEQ
    //       3'b001: branch_taken = (!alu_zero);            // BNE
    //       3'b100: branch_taken = (alu_result[0]);        // BLT
    //       3'b101: branch_taken = (!alu_result[0]);       // BGE
    //       3'b110: branch_taken = (!alu_zero || alu_result[0]); // BLTU
    //       3'b111: branch_taken = (alu_zero && !alu_result[0]); // BGEU
    //   endcase

    // next_pc 优先级：JALR > JAL > Branch > 顺序

    //--------------------------------------------------------------------------
    // 输出连接
    //--------------------------------------------------------------------------
    assign pc_o        = pc;
    assign mem_addr_o  = alu_result;    // 数据地址 = ALU 结果
    assign mem_wdata_o = rd2;           // 写数据 = rs2
    assign mem_write_o = mem_write;
    assign mem_read_o  = mem_read;

endmodule
