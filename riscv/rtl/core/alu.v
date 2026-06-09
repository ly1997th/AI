//==============================================================================
// alu.v — 算术逻辑单元 (Arithmetic Logic Unit)
//==============================================================================
//
// 【电路架构】
// ┌─────────────────────────────────────────────────────────────┐
// │  功能：执行 RV32I 全部算术/逻辑运算，纯组合逻辑。              │
// │                                                              │
// │  数据通路（32-bit × 2 输入 → 32-bit 输出）：                   │
// │                                                              │
// │    a[31:0] ─┬─→ [Adder] ──────┐                              │
// │             │                 │                              │
// │    b[31:0] ─┤                 │                              │
// │             ├─→ [XOR Array] ──┤                              │
// │             │                 │                              │
// │             ├─→ [AND/OR Arr] ─┤                              │
// │             │                 ├─→ [Result MUX] ──→ result    │
// │             ├─→ [Shifter] ────┤       ↑                      │
// │             │                 │    alu_control[3:0]           │
// │             ├─→ [Comparator] ─┘    (MUX 选择信号)              │
// │             │                                                │
// │             └─→ [zero detect] ──→ zero                       │
// │                   (NOR tree)                                  │
// │                                                              │
// │  控制通路（4-bit alu_control → 10路MUX选择 + 运算子使能）：     │
// │    alu_control[3:0] ──→ 各算术单元的条件选择输入端              │
// │                         ──→ Result MUX 的 10:1 选择            │
// │                                                              │
// │  路径分离分析：                                               │
// │    - 数据通路：a,b 均为32-bit，经不同运算阵列后汇聚到MUX        │
// │    - 控制通路：alu_control 4-bit 扇出至所有运算子单元的选择端    │
// │    - 重汇聚点：Result MUX（多条不同延迟路径汇集，需平衡）        │
// │    - 关键路径：Adder（进位链）> Shifter > Comparator            │
// └─────────────────────────────────────────────────────────────┘
//
// 【宏单元映射与PPA评估】
// ┌─────────────────────────────────────────────────────────────┐
// │  宏单元清单：                                                 │
// │    · 1× 32-bit Adder（ADD/SUB 共用，SUB=a+~b+1）              │
// │    · 1× 32-bit Barrel Shifter（SLL/SRL/SRA 共用）             │
// │    · 1× 32-bit XOR Array（32个并行XOR门）                     │
// │    · 1× 32-bit AND/OR Array（AOI复合门阵列）                  │
// │    · 1× 32-bit Comparator（有符号/无符号，级联比较链）          │
// │    · 1× 10-to-1 32-bit MUX（结果选择，面积最大项之一）          │
// │    · 1× 32-input NOR（zero 检测，1个NOR门→树形扩展）            │
// │                                                              │
// │  互联关系：                                                   │
// │    · a,b → 所有运算单元（扇出=6，属于中高扇出）                  │
// │    · alu_control → Result MUX select（扇出=4-bit，无缓冲压力） │
// │    · 重汇聚：a,b 经不同延迟路径后在 Result MUX 汇聚             │
// │                                                              │
// │  PPA评估（精度分级：低敏感度—基于逻辑分析）：                    │
// │    · 面积：Adder(~200门) + Shifter(~300门) + Comp(~100门)     │
// │           + MUX10:1_32b(~300门) ≈ 1000门当量（中等规模）       │
// │    · 时序：关键路径 = Adder进位链(~10级) + MUX(~2级) ≈ 12级    │
// │            Barrel Shifter 的MUX网络深度≈5级，可能成为次关键路径 │
// │    · 功耗：组合逻辑动态功耗与输入翻转率强相关                    │
// │    · 优化方向：可用超前进位加法器替换行波进位以压缩关键路径       │
// └─────────────────────────────────────────────────────────────┘
//
// 【RTL代码】
//==============================================================================

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);

    // 运算操作码（与 control_unit ALU Decoder 输出一致）
    localparam ALU_ADD  = 4'b0000;  // ADD:  result = a + b
    localparam ALU_SUB  = 4'b0001;  // SUB:  result = a - b
    localparam ALU_AND  = 4'b0010;  // AND:  result = a & b
    localparam ALU_OR   = 4'b0011;  // OR:   result = a | b
    localparam ALU_XOR  = 4'b0100;  // XOR:  result = a ^ b
    localparam ALU_SLL  = 4'b0101;  // SLL:  result = a << b[4:0]
    localparam ALU_SRL  = 4'b0110;  // SRL:  result = a >> b[4:0]
    localparam ALU_SRA  = 4'b0111;  // SRA:  result = a >>> b[4:0] (arithmetic)
    localparam ALU_SLT  = 4'b1000;  // SLT:  result = (a < b) ? 1 : 0 (signed)
    localparam ALU_SLTU = 4'b1001;  // SLTU: result = (a < b) ? 1 : 0 (unsigned)

    // 10-to-1 32-bit MUX：按 alu_control 选择运算结果
    // 代数化解：每个 case 分支对应一条独立的数据路径
    always @(*) begin
        case (alu_control)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            default:  result = 32'b0;
        endcase
    end

    // Zero 检测：32-input NOR（result 全零 → zero=1）
    assign zero = (result == 32'b0);

endmodule
