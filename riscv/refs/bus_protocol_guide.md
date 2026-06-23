# 总线协议规范

> 本文档定义逻辑设计中的标准总线协议。

---

## 一、总线层次说明

### 1.1 总线类型层级

| 层级 | 总线类型 | 案例 | 核心关注点 |
|------|---------|------|-----------|
| 板间通信接口 | 物理层 | VGA、HDMI、RS-232 | 信号转换、传输距离、信噪比 |
| 片间通信接口 | 物理层 | I2C、UART、SPI | 传输距离、速度 |
| IP间通信总线 | 协议层 | APB、AXI | 可扩展性、灵活性、规范性 |
| **模块间通信总线** | **逻辑层** | **taskbus/vldbus/hskbus** | **简洁、易用、低成本** |
| 物理实体总线 | 物理层 | 单口/伪双口/真双口mem | 面积、功耗、时序 |

### 1.2 命名规则

【规则】apb、axi、lb都不加bus后缀，vldbus、hskbus、clkbus、taskbus有bus后缀

---

## 二、总线顺序规范（强制）

### 2.1 总体原则

【规则】总线信号不仅要求名称、参数名符合规范，还需要保证**信号声明及例化的顺序、个数**符合规范

【规则】参考业内标准总线(如AXI)，结合各总线语义逻辑，确定**总线顺序**如下：

1. `valid/ready/dat`：核心诉求是握手，因此dat放后；valid是前有数、ready是后有空，因此valid在前
2. `en/addr/dat`：核心述求是提请求，之后描述什么地方、什么内容，因此en在前
3. `dat/vld`：核心述求是数据的处理，vld只是修饰，表示何时可用，因此dat在前
4. `valid_lst`、`vld_lst`：作为追加信号，放在总线最后面，而不是紧跟valid/vld之后
5. `wr_be`：用来修饰wr_dat，而不是wr_addr，位宽也只和DWIDTH相关，因此在写总线拆分为aw和w时，属于w总线，且紧跟在dat之后

### 2.2 总线信号后缀统一规则

【规则】**总线信号后缀名称需统一，不允许修改，仅允许增加前缀**

【规则】**多组总线信号MUX时需基于总线进行**

【指导】**模块接口需尽量仅由总线构成**

【指导】多组总线信号用电平信号控制MUX，而不是en或vld信号，避免因为en或vld的频繁变化导致翻转功耗的增加

---
## 三、逻辑总线协议详解

### 3.1 taskbus（sox/eox/pd）- 任务级控制

#### 3.1.1 术语说明

| 术语 | 含义 |
|------|------|
| pk_sox/eox/xwk | pk是packet的缩写，表示多组打包；x代指任务颗粒度（f=frame, l=line, p=packet）；xwk是x_working的缩写 |
| pd | packet data的缩写，用于参数的打包 |

#### 3.1.2 接口信号

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| _sox | 1 | Master2Slave | 事务启动脉冲 |
| _eox | 1 | Slave2Master | 事务结束脉冲，可细分为eox_head和eox_tail |
| _pd | PD_WIDTH | Master2Slave | 事务指令（packet_data的缩写） |
| _pdout（可选） | | Slave2Master | 事务执行完成后return的信息 |
| _xwk（可选） | 1 | Slave2Master | 事务正在工作的状态标志 |

#### 3.1.3 协议规则（强制）

【规则1】和sox配套的pd（称为sox_pd）需要在sox时刻可用

【规则2】和en/vld/xwk配套的pd（称为xwk_pd）需要在en/vld/xwk时刻可用，且在一次xwk期间不允许变化

【规则3】sox/eox/xwk的相位关系需规范：sox后xwk拉高、eox后xwk拉低

【规则4】**sox_pd和xwk_pd不可混为一个信号**（必须解耦）

【规则5】sox_cnt/eox_cnt的使用规范：产生sox_mode要用sox_cnt，产生lst_eox要用eox_cnt

【规则6】循环任务分解中单次任务耗时不能为0

【规则7】多组sox/eox/pd的挑选时序规范：
- pk_sox、sox、sox_pd对齐
- xwk_pd、xwk、en/vld对齐
- eox、pk_eox对齐
- sox_pd为组合逻辑挑选得到
- xwk_pd通过在sox时刻对sox_pd进行锁存来实现

【规则8】sox/sox_pd的时序问题统一通过**增加气泡时间片**的方式解决

【规则9】下游模块的pd产生规范：xwk_pd_dly除了通过对xwk_pd打拍外，还可以通过pk_sox_dly从pk_pd挑选后锁存实现

---

### 3.2 vldbus（dat/vld）- 单向数据流

#### 3.2.1 接口信号

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| _dat | DWIDTH | Master2Slave | 数据 |
| _vld | 1 | Master2Slave | 传输有效 |
| _vld_xlst（可选） | 1 | Master2Slave | x循环层级的最后一个valid |
| _vld_xfst（可选） | 1 | Master2Slave | x循环层级的第一个valid |

#### 3.2.2 协议规则

【规则1】vld_xlst/xfst是一种特殊的vld，禁止vld_xlst/xfst为1时vld为0

---
### 3.3 hskbus（dat/valid/ready）- 双向握手

#### 3.3.1 术语说明

【规则】为区分"前有数状态"和"握手行为"，用valid表示状态、vld表示行为，约定vld=ready&&valid

| 术语 | 含义 |
|------|------|
| valid | 信息有效的一种状态，对应前有数 |
| ready | 接收方就绪的一种状态，对应后有空 |
| vld | 信息有效的一种操作/行为 |

#### 3.3.2 接口信号

| Signal | Width | Direction | Description |
|--------|-------|-----------|-------------|
| _valid | 1 | Master2Slave | 前级模块数据传输有效 |
| _ready | 1 | Slave2Master | 后级模块数据接收有效 |
| _dat | DWIDTH | Master2Slave | 传输的数据 |
| _valid_lst（可选） | 1 | Master2Slave | 最后一个valid |

#### 3.3.3 协议规则（强制）

【规则1.1】**valid禁止撤销**：valid拉高后，在完成与ready握手之前，禁止自行拉低

【规则1.2】**数据稳定性**：valid拉高后，在完成与ready握手之前，与valid关联的data禁止翻转

【规则2.1】**禁止反向依赖**：master的valid状态不能依赖slave端与该信息配套的ready状态来产生

【指导】slaver端的ready状态可以依赖master端的valid状态产生，但尽量避免

【规则3】valid_lst是一种特殊的valid，valid_lst为1时，valid必须为1

【规则】**禁止模块级的接口总线中包含valid_fst**，模块内有需求时，使用标准组件基于valid和valid_lst在本地产生

【建议】避免模块的接口总线中包含valid_lst，以降低设计复杂度

---
### 3.4 fifobus - FIFO接口

#### 3.4.1 术语说明

| 术语 | 含义 |
|------|------|
| fifo | First Input First Output，先入先出 |
| fwft | First Word Fall Through，在rd_en发起前就把数据放到接口上。典型的fifo读延时是1，fwft_fifo的读延时为0 |
| avcnt | available count，可用数据量 |

#### 3.4.2 接口信号

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| _srst | To FIFO | 1 | 同步复位 |
| _wr_en | To FIFO | 1 | 写使能 |
| _wr_dat | To FIFO | _DWIDTH | 写数据（注意：不是din） |
| _wr_avcnt | From FIFO | _NWIDTH | 可写个数 |
| _wr_full | From FIFO | 1 | 写总线的满 |
| _rd_en | To FIFO | 1 | 读使能 |
| _rd_dat | From FIFO | _DWIDTH | 读数据（注意：不是dout） |
| _rd_vld(可选) | From FIFO | 1 | 读数据有效，相比rd_en延时RD_DLY，fwft型没有该信号 |
| _rd_avcnt | From FIFO | _NWIDTH | 可读个数 |
| _rd_empty | From FIFO | 1 | 读总线的空 |
| _fifo_error | From FIFO | 2 | 空读满写错误 |

#### 3.4.3 重要命名变更

【重要】fifobus总线规范更新：
- **旧规范**：wr_en → din → rd_en → dout
- **新规范**：**i_dat/i_vld平级**，不允许din/din_vld，因为dat和vld是平级的
- **原则**：不允许有din/dout命名，使用wr_dat/rd_dat

#### 3.4.4 协议规则

【规则1.1】rd_empty拉低后，在rd_clk采样到rd_en为1前，禁止自行拉高

【规则1.2】wr_full拉低后，在rd_clk采样到wr_en为1前，禁止自行拉高

【规则1.3】rd_avcnt在rd_clk采样到rd_en为1时，一次最多只能减小1

【规则1.4】rd_avcnt在rd_clk采样到rd_en为0时，不允许减小

【规则1.5】wr_avcnt在wr_clk采样到wr_en为1时，一次最多只能减小1

【规则1.6】wr_avcnt在wr_clk采样到wr_en为0时，不允许减小

【规则1.7】rd_empty为1时rd_avcnt必须为0，反之亦然

【规则1.8】wr_full为1时wr_avcnt必须为0，反之亦然

---
### 3.5 bufbus - 存储器访问

#### 3.5.1 术语说明

| 术语 | 含义 |
|------|------|
| _byte | 该后缀表示支持byte_enable |
| _bit | 该后缀表示支持bit_enable |
| 1P | 单口，同一时刻只能读或写 |
| 2P | 伪双口，同一时刻能同时读写 |
| DP | 真双口，等价于两个单口 |
| C2P | 定制伪双口（Customized_2P） |

#### 3.5.2 接口信号

| Signal | Direction | Width |
|--------|-----------|-------|
| _buf_wr_en | To Buf | 1 |
| _buf_wr_addr | To Buf | _BUF_AWIDTH |
| _buf_wr_dat | To Buf | _BUF_DWIDTH |
| _buf_wr_be | To Buf | _BUF_DWIDTH or _BUF_DWIDTH/8 |
| _buf_rd_en | To Buf | 1 |
| _buf_rd_addr | To Buf | _BUF_AWIDTH |
| _buf_rd_dat | From Buf | _BUF_DWIDTH |
| _buf_rd_vld | From Buf | 1 |

【指导】避免通过buf_rd_en本地延迟得到buf_rd_vld，这样hold_timing差，应该使用buf_rd_dat的随路vld

#### 3.5.3 协议规则

【规则1】1PBUF同一时刻只能读或写

【规则2】2PBUF同一时刻能同时读写，但地址相同时，默认读出老数据

【规则3】用DPRAM搭建出来的BUF，两路BUF总线不允许同时写同一地址

【规则4】用DPRAM搭建出来的BUF，两路BUF总线分别读写同一地址时，默认读出老数据

【规则5】C2PBUF同一时刻能同时读写，但地址相同时，默认读出老数据

【规则6】C2PBUF每次任务的读次数必须是偶数，写次数同样

【规则7】C2PBUF读写使能可以不连续，但地址必须偶奇连续且成对

【规则8】C2PBUF读偶地址后，配套奇地址数据读出前不允许写该奇地址

---
## 四、标准总线（IP间）

### 4.1 AXI总线

默认采用AXI4协议，默认不支持out_of_order。

| AXI Signal | Typical Width | Description |
|------------|---------------|-------------|
| ID | 4 | ID |
| VALID | 1 | Valid |
| ADDR | 32 | Address |
| LEN | 8 | Burst length |
| SIZE | 3 | Burst size，**本IP中固定为4（16bytes）** |
| BURST | 2 | Burst type，always **INCR** |
| LOCK | 1 | Lock type，always **NORMAL** |
| CACHE | 4 | Cache type，always **Noncacheable** |
| PROT | 3 | Protection type |
| QOS | 4 | always **NORMAL** |
| DATA | 128或32 | Data |
| STRB | 16或4 | Strobe byte lane |
| RESP | 2 | Response |

### 4.2 APB总线

| Name | Direction | Width | Description |
|------|-----------|-------|-------------|
| _paddr | Master2Slave | X | APB address |
| _psel | Master2Slave | 1 | APB select |
| _penable | Master2Slave | 1 | APB write enable |
| _pwrite | Master2Slave | 1 | APB write indication |
| _pwdata | Master2Slave | 32 | APB write data |
| _prdata | Slave2Master | 32 | APB read data |
| _prready | Slave2Master | 1 | APB read ready |
| _pslverr | Slave2Master | 1 | APB slave error |

---

## 五、总线选型决策

### 5.1 按场景选择总线

| 场景 | 推荐总线 | 说明 |
|------|---------|------|
| 任务级控制（帧/行/包） | taskbus | sof/eof/pd，生命周期管理 |
| 单向数据流传输 | vldbus | dat/vld，简单有效指示 |
| 需要流控的数据传输 | hskbus | valid/ready/dat，双向握手 |
| FIFO接口 | fifobus | wr_en/wr_dat/rd_en/rd_dat |
| 存储器随机访问 | bufbus | en/addr/dat，地址访问 |
| 资源仲裁 | reqgrt | req/grt，请求授权 |

### 5.2 总线转换

| 转换类型 | 方法 |
|---------|------|
| hskbus → vldbus | 握手成功后输出vld |
| vldbus → hskbus | 增加ready信号，处理反压 |
| taskbus → vldbus | 在working期间产生vld |

---
## 六、总线使用检查清单

- [ ] 总线信号顺序是否符合规范？
- [ ] 总线信号后缀是否正确？
- [ ] 多组总线MUX是否基于总线进行？
- [ ] taskbus的sox_pd和xwk_pd是否解耦？
- [ ] hskbus的valid是否禁止撤销？
- [ ] hskbus的valid期间数据是否稳定？
- [ ] 是否存在反向依赖（master valid依赖slave ready）？
- [ ] fifobus是否使用wr_dat/rd_dat（非din/dout）？
- [ ] 模块接口是否尽量由总线构成？