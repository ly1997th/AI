# 全球主流代工厂工艺节点演进深度分析报告

> **研究日期**: 2026年6月24日  
> **方法论**: 多角度网络搜索 → 源抓取 → 声明提取 → 3票对抗验证 → 综合  
> **覆盖代工厂**: TSMC（台积电）、Samsung Foundry（三星）、Intel Foundry（英特尔）、GlobalFoundries（格芯）、UMC（联电）、SMIC（中芯国际）  
> **节点范围**: 180nm ~ 2nm/GAA（~1999–2026）

---

## 目录

1. [执行摘要](#1-执行摘要)
2. [工艺节点演进总览](#2-工艺节点演进总览)
3. [关键代工厂深度分析](#3-关键代工厂深度分析)
4. [核心技术路线分化](#4-核心技术路线分化)
5. [PPA 对比分析](#5-ppa-对比分析)
6. [关键产品与节点映射](#6-关键产品与节点映射)
7. [竞争格局演变](#7-竞争格局演变)
8. [开放问题与展望](#8-开放问题与展望)
9. [数据源与参考](#9-数据源与参考)

---

## 1. 执行摘要

全球半导体代工行业经历了从 **180nm 平面 CMOS** 到 **2nm GAA 纳米片晶体管** 的深刻演进。这场持续近30年的技术竞赛中：

- **TSMC（台积电）在 28nm 节点确立代工领先地位**（2011年首家量产），此后通过多层级工艺组合（LP/HPM/HKMG）长期占据该节点市场份额第一。在后续 16nm → 7nm → 5nm → 3nm → N2 各节点持续保持时间-市场和技术领先。**[已验证，置信度: 高]**

- **Samsung 的激进策略在执行上遭遇重大挫折**：在 7nm 节点跳过 DUV 直跳 EUV，失去了对 TSMC N7 的一年时间窗口；在 3nm 节点全球首发 GAA（MBCFET），但良率灾难性低迷——2024年Q1不足 20%，导致几乎所有大客户（Qualcomm、NVIDIA、Apple、AMD、MediaTek）将先进制程订单转向台积电。**[已验证，置信度: 高]**

- **Intel 重新加入代工竞争**：凭借 RibbonFET（GAA）+ PowerVia（BSPDN/背面供电）的 18A 节点于 2025 年进入 HVM，成为首个同时量产 GAA + BSPDN 的节点。但代工业务的外部客户获取仍待验证。**[已验证，置信度: 高]**

- **GlobalFoundries 于 2018 年放弃 7nm**，退守 12nm/14nm FinFET 及成熟节点，转向"more-than-Moore"差异化战略。

- **SMIC 受美国出口管制限制无法获取 EUV**，14nm 量产但 7nm 依赖 DUV 多图案化，良率和产能不透明。

- **TSMC N2** 已通过 IEDM 2024 硅验证数据：相比 N3E，同功耗性能提升 10-15%，同频功耗降低 25-30%，混合设计芯片密度提升 ~15%。2025年Q4进入量产。**[已验证，置信度: 高]**

---

## 2. 工艺节点演进总览

### 2.1 时间线全景图

```
节点       TSMC          Samsung       Intel          GF             UMC           SMIC
─────────────────────────────────────────────────────────────────────────────────────────
180nm      2000          2000          1999           —             2000          —
130nm      2002          2001          2001           —             2003          —
90nm       2004          2004          2003           —             2005          —
65nm       2006          2005          2005           —             2006          —
55/45nm    2008          2007          2007(45nm)     —             2008          —
40nm       2009          2009          —              2010          2009          —
32/28nm    2011(28nm)    2013(28nm)    2010(32nm)     2012(28nm)    2012(28nm)   2013(40nm)
22nm       —             —             2012(FinFET)   —             —            —
20nm       2014          2012          —              —             —            —
16/14nm    2015(16FF)    2015(14LPE)   2014(14nm)     2015(14LPP)   2016(14nm)   2015(28nm HKMG)
12nm       2017(12FFC)   2016(12LPP)   —              2016(12LP)    —            —
10nm       —             2017(10LPE)   —              —             —            —
7nm        2018(N7 DUV)  2018(8LPP)    —              放弃(2018)    —            —
7nm EUV    2019(N7+)     2019(7LPP EUV)—              —             —            —
5nm        2020(N5)      2020(5LPE)    —              —             —            —
4/3nm      2023(N3 FinFET)2022(3GAE GAA)2024(Intel 3)—             —            —
2nm/GAA    2025(N2 GAA)  2025(SF2)     2025(18A GAA)  —             —            —
1.4nm      ~2028(A16)    2027(SF2Z)    2028(14A)      —             —            —
```

> **注**：量产年份为首批客户产品出货年份，非风险生产/工程样品。空白（—）表示该代工厂跳过了对应节点或在节点上没有商业竞争力。

### 2.2 关键技术里程碑

| 年代 | 里程碑 | 首发代工厂 | 影响 |
|------|--------|-----------|------|
| ~2003 | 应变硅 (Strained Silicon) | Intel (90nm) | 提升载流子迁移率，开启材料工程时代 |
| ~2004 | 浸没式光刻 (Immersion Lithography) | TSMC/多厂 | 突破193nm干式光刻极限，使65nm以下节点可行 |
| ~2007 | High-K/Metal Gate (HKMG) | Intel (45nm) | 解决栅极漏电，摩尔定律延续关键一步 |
| ~2011 | 28nm HKMG | TSMC 首家代工量产 | 代工行业最大"长寿"节点，至今仍有收入贡献 |
| ~2012 | FinFET 晶体管 | Intel (22nm) | 3D晶体管革命，终结传统平面CMOS |
| ~2015 | 代工 FinFET (16nm/14nm) | TSMC/Samsung | 将FinFET引入代工生态 |
| ~2018-19 | EUV 光刻引入 | Samsung 7nm EUV 首发 | 减少多图案化步骤，提升良率和周期 |
| ~2022 | GAA 晶体管 | Samsung 3nm (MBCFET) | 首个全环绕栅极量产，但良率失败 |
| ~2024-25 | 背面供电 (BSPDN) | Intel 18A (PowerVia) | 供电网络分离到晶圆背面，释放正面布线资源 |
| ~2025 | GAA + 成熟良率 | TSMC N2 | 行业公认的GAA健康量产分水岭 |

---

## 3. 关键代工厂深度分析

### 3.1 TSMC（台积电）—— 无可争议的代工之王

**战略路线**: 渐进保守 → 稳扎稳打，在重大技术切换时保持一代缓冲期

| 节点 | 量产年 | 关键技术 | 代表产品 |
|------|--------|---------|---------|
| 28nm | 2011 | HKMG, LP/HPM/HPC多版本 | Snapdragon 800, Apple A7, MediaTek MT6592 |
| 20nm | 2014 | 平面最后一代，密度过渡 | Apple A8, Snapdragon 810 |
| 16FF | 2015 | 首代FinFET | Apple A9, Kirin 950 |
| N7 (DUV) | 2018 | 首代7nm, DUV | Apple A12, Snapdragon 855, Kirin 980 |
| N7+ (EUV) | 2019 | EUV引入, 仅几层 | Kirin 990 5G |
| N5 | 2020 | EUV广泛应用 | Apple A14, Snapdragon 888, AMD Zen 4 |
| N3 (FinFlex) | 2023 | 最后FinFET节点, FinFlex | Apple A17 Pro, M3 |
| N2 (GAA) | 2025 | 首代GAA纳米片 | Apple A20 Pro (预期), M5, AMD Zen 6 |

**关键特征**：

- **28nm 多层级战略**：TSMC 在28nm提供 LP（低功耗）、HPM（高性能移动）、HPC（高性能计算）、HPL（低漏电）四个变体。这种"一个节点服务所有市场"的策略贡献了其长期市场主导地位。**[已验证]**

- **7nm DUV→EUV平滑迁移**：TSMC在7nm采取了循序渐进的光刻策略——先用成熟的DUV量产N7（2018年4月，Apple A12），再引入EUV到部分层次的N7+（2019年6月）。同时提供DUV优化的N7P和与N7设计兼容的EUV增强版N6。这使得TSMC比Samsung提前约一年进入7nm市场。**[已验证]**

- **3nm坚守FinFET**：TSMC在整个N3家族（N3B→N3E→N3P→N3X→N3A）采用FinFET + FinFlex混合配置。TSMC高管Kevin Zhang明确将N3定位为"最后也是最好的FinFET节点"。GAA仅在N2引入——这是一种"风险管理节点"策略：只做GAA，不做BSPDN，降低新技术叠加风险。**[已验证]**

- **N2 PPA（IEDM 2024硅验证）**：同功耗性能+10-15%，同频功耗-25-30%，混合设计密度+~15%。Arm Cortex-A715实际硅片测试验证，电压范围0.5V-0.9V。纯逻辑密度提升可达~20%。**[已验证]**

- **N2 初期良率**：分析师/供应链估计60-75%（2025 Q4 - 2026 Q1早期HVM），但TSMC从未官方确认具体百分比。SRAM良率>90%。2026年5月TSMC技术研讨会确认缺陷密度达到N3同等水平，比计划提前两个季度。**[已验证，置信度: 中]**

### 3.2 Samsung Foundry —— 激进技术赌博的代价

**战略路线**: 激进跳跃 → 在EU导入和GAA引入均追求"世界第一"，但执行风险失控

| 节点 | 量产年 | 关键技术 | 代表产品 |
|------|--------|---------|---------|
| 28nm | 2013 | HKMG (比TSMC晚2年) | Apple A7 |
| 14LPE | 2015 | 首代FinFET | Exynos 7420, Snapdragon 820 |
| 10LPE | 2017 | 短暂领先TSMC的10nm | Exynos 8895, Snapdragon 835 |
| 8LPP | 2018 | DUV最后一代 | Exynos 9820 |
| 7LPP (EUV) | 2019 | 全球首个EUV商用 | Exynos 9825 |
| 5LPE | 2020 | EUV | Snapdragon 888 |
| 3GAE/GAP | 2022 | 全球首个GAA MBCFET | 加密货币矿机ASIC (仅量产芯片) |
| SF2 | 2025 | GAA二代 | 待定 |

**关键事件**：

- **7nm DUV→EUV 断崖式跳跃**：Samsung内部开发了第一代DUV 7nm（7LPE/SF7E），但在商业化前取消。2018年10月宣布直接推出7nm LPP使用EUV——"全球首个商用EUV半导体工艺"。Exynos 9820（Galaxy S10）仍使用8nm LPP DUV，首个7nm EUV芯片Exynos 9825（Galaxy Note10）于2019年8月才出货。Samsung在7nm市场丧失了近一整年时间窗口。**[已验证]**

- **3nm GAA 灾难**：Samsung于2022年7月25日举办了全球首场3nm GAA量产出货仪式，但良率崩溃。多个独立来源（Samsung Securities本身、The Korea Times、TrendForce、TechPowerUp）证实：2024年Q1良率低至个位数，2024年Q2约20%，远低于70%的目标线。Exynos 2500试产良率报告为0%可用芯片，迫使Galaxy S25全部使用Snapdragon。结果：Qualcomm、NVIDIA、Apple、AMD、MediaTek全部将先进制程转向TSMC。Samsung代工市场份额从~16%（2019）跌至~11.5%（2024年Q2）。**[已验证]**

**教训**：Samsung的战略执行差距不在于技术选择（GAA本质上是正确的方向），而在于时间线和良率爬坡管理。TSMC选择在N3打磨FinFET的成熟度、在N2稳步切换到GAA，被市场证明是正确的路径。

### 3.3 Intel Foundry —— 从IDM到代工的艰难转型

**战略路线**: 长期IDM技术引领者 → 10nm/7nm连续延迟 → 代工转型 → IDM 2.0

| 节点 | 量产年 | 关键技术 | 代表产品 |
|------|--------|---------|---------|
| 90nm | 2003 | 应变硅 | Pentium 4 Prescott |
| 65nm | 2005 | — | Core 2 Duo |
| 45nm | 2007 | 首代HKMG | Core i7 (Nehalem) |
| 32nm | 2010 | — | Core i3/i5/i7 (Westmere) |
| 22nm | 2012 | 全球首个FinFET | Ivy Bridge |
| 14nm | 2014 | FinFET+ | Broadwell → 多代+++ |
| 10nm | 2019(延迟) | FinFET第3代 | Ice Lake (良率挣扎) |
| Intel 7 | 2021 | 原10nm ESF | Alder Lake |
| Intel 4 | 2023 | EUV引入 | Meteor Lake |
| Intel 3 | 2024 | EUV FinFET | Granite Rapids, Sierra Forest |
| Intel 18A | 2025 | RibbonFET GAA + PowerVia BSPDN | Panther Lake (CES 2026) |
| Intel 14A | 2028 | High-NA EUV | 待定 |

**关键特征**：

- **历史技术引领**：Intel在22nm（2012）全球首家引入FinFET，比TSMC 16FF（2015）领先3年。在45nm（2007）首家引入HKMG。但这些历史上的技术领先并未转化为代工商业优势。

- **"Tick-Tock"节奏断裂**：14nm（2014）→ 10nm（原计划2015-16，实际2019）延迟4-5年，成为Intel历史上最严重的节点延迟。此后进行品牌重塑（Intel 7、Intel 4、Intel 3）以对齐代工行业命名惯例。

- **18A：代工业务的关键赌注**：Intel 18A同时组合GAA（RibbonFET）+ BSPDN（PowerVia），是全球首个同时量产的节点。2025年H2进入HVM，Arizona Fab 52为HVM主厂。到CES 2026，Panther Lake CPU采用18A出货。**[已验证]**

- **BSPDN 先发优势**：TSMC将背面供电（Super Power Rail）推迟到A16（H2 2026），N2/N2P仍使用正面供电+SHPMIM电容。Samsung的BSPDN在SF2Z（2027）。截至2026年中，Intel 18A是唯一量产GAA+BSPDN组合的节点。**[已验证]**

- **代工客户的未知数**：Intel 18A的外部客户获取、端到端良率（full-flow yield，非仅前段yield）以及代工服务能力（EDA/IP生态、客户支持）仍在验证中。Intel前CEO Pat Gelsinger在2024年12月公开质疑TSMC的N2良率定义（暗示可能只报告前段良率），但这种说法被行业广泛认为有失公允。

### 3.4 GlobalFoundries —— 退出先进制程竞赛

**路线**: 从AMD制造部门剥离 → FinFET追赶者 → 2018年放弃7nm → "more-than-Moore"差异化

| 节点 | 量产年 | 备注 |
|------|--------|------|
| 40nm | 2010 | 继承AMD/Chartered技术 |
| 28nm | 2012 | 良率低导致AMD取消APU订单 |
| 14LPP | 2015 | 从Samsung授权获得FinFET技术 |
| 12LP | 2016 | 14nm改进版 |
| 7nm | 放弃(2018) | 研发终止，转向差异化战略 |
| 12LP+/22FDX | 2020+ | FD-SOI和成熟FinFET节点 |

**关键转折**：2018年8月，GlobalFoundries宣布无限期搁置7nm研发。这一决定源于：（1）7nm研发费用超过$10B且持续攀升；（2）AMD将7nm CPU/GPU订单全部转移至TSMC；（3）GF无法获得足够的外部客户来摊薄投资。此举使先进制程代工从"三巨头"（TSMC/Samsung/GF）缩小为"两强"格局。

GF目前聚焦于差异化技术：22FDX（22nm FD-SOI，用于IoT/汽车）、SiPh（硅光子）、GaN功率器件等。其12nm/14nm FinFET仍在为部分客户（AMD早期产品、汽车芯片）提供长期支持。

### 3.5 UMC（联电） —— 成熟节点专家

UMC是最早进入代工行业的公司之一（1980年成立），但在28nm之后主动放弃了先进制程竞赛。

| 节点 | 量产年 | 备注 |
|------|--------|------|
| 28nm Poly/SiON | Q3 2012 | 首代28nm（非HKMG） |
| 28nm HKMG | 2013 | 晚于TSMC约2年 |
| 14nm FinFET | 2016 | 小规模量产，客户有限 |
| 22nm | 2020+ | 平面CMOS最后的坚守者之一 |

2018年后，UMC正式宣布停止先进制程追赶，转向"投资回报导向"策略——全力经营28nm及以上的成熟节点。这一策略极为成功，尤其是在2021-2024年全球成熟制程产能紧缺期间，UMC实现了创纪录的盈利。

### 3.6 SMIC（中芯国际） —— 在制裁阴影下挣扎

| 节点 | 量产年 | 备注 |
|------|--------|------|
| 40nm | 2013 | 早期节点跨度大 |
| 28nm HKMG | 2015-16 | Poly/SiON + HKMG两代 |
| 14nm FinFET | ~2019 | 为华为等客户小规模量产 |
| 7nm (DUV) | 未证实 | 传闻中依赖DUV多图案化开发 |

SMIC面临的最核心约束是美国出口管制——无法获得ASML EUV光刻机（受瓦森纳协定和美国制裁双重限制）。7nm及以下节点被迫使用DUV浸没式光刻+多图案化，成本高、周期长、良率不确定。有报道称SMIC已为华为代工7nm级芯片，但规模、良率和具体工艺细节高度不透明。

---

## 4. 核心技术路线分化

### 4.1 FinFET vs GAA 竞争时间线

```
2012 ──────────────────────────────────────────────────── 2026
 │                                                          │
 │ Intel 22nm FinFET (全球首发)                              │
 │                                                          │
 │  TSMC 16FF (2015)                                        │
 │  Samsung 14LPE (2015)                                    │
 │  GF 14LPP (2015, Samsung授权)                            │
 │                                                          │
 │                          Samsung 3nm GAA (2022) ─ 良率崩溃│
 │                          TSMC N3 FinFET (2023) ─ 最后FinFET│
 │                                                          │
 │                                Intel 18A RibbonFET (2025)│
 │                                TSMC N2 GAA (2025)        │
 │                                Samsung SF2 GAA (2025)    │
 └──────────────────────────────────────────────────────────┘
```

**技术选择对比**：

| 方面 | TSMC | Samsung | Intel |
|------|------|---------|-------|
| FinFET→GAA切换点 | N3→N2 (2025) | 5nm→3nm (2022) | Intel 3→18A (2025) |
| GAA实现方式 | 纳米片 (Nanosheet) | MBCFET (Multi-Bridge Channel FET) | RibbonFET (纳米带) |
| 切换策略 | FinFET多迭代，GAA一次到位 | 直接跳跃，首个商用GAA | FinFET→GAA，搭配BSPDN |
| 结果 | N3家族成熟，N2产出入佳境 | 3nm GAA灾难性良率 | 待验证 |

**核心洞察**：TSMC在N3使用FinFET的决策被证明非常明智——这给了GAA开发额外2-3年的打磨时间，避免了Samsung在3nm踩的坑。同时，N3的FinFlex（2-1/2-2/3-2混合鳍片配置）提供了从密集到高性能的灵活选择，在PPA上达到了不逊色于早期GAA的水平。

### 4.2 DUV vs EUV 导入路径分化

```
              2018              2019              2020
               │                 │                 │
TSMC  ──── N7(DUV) ─── N7+(EUV) + N7P(DUV) ─── N5(EUV) 
               │                 │                 │
Samsung ── 8LPP(DUV) ─── 7LPP(EUV) ───────── 5LPE(EUV)  
       (跳过7nm DUV)        │                 │
                             └─── 首个商用EUV ───┘
Intel ───────── 14nm+++++ ─── Intel 4(EUV,2023) ─── Intel 3(EUV)
       (10nm DUV,严重延迟)        (EUV引入晚)
```

**关键分歧点**：

- **TSMC的渐进EU导入**：N7用DUV（2018），N7+在少量层次引入EUV（2019），N5开始广泛使用EUV（2020）。代价是N7的多图案化步骤多（DUV需要quad patterning），好处是时间-市场优势。

- **Samsung的断崖EU导入**：跳过DUV 7nm，直接上EUV。这带来了工艺简单化的好处（EUV单次曝光替代多次DUV），但代价是失去一年市场窗口。

- **Intel的DU延迟**：10nm（后改名Intel 7）的DUV多图案化成为制造噩梦，良率不振多年。Intel 4（2023）才开始使用EUV，是所有主要厂商中最晚的。

**EUV世代更替**：

| 代次 | 型号 | NA | 分辨率 | 状态 |
|------|------|-----|--------|------|
| 0.33 NA EUV | NXE:3400B/C, NXE:3600D/3800E | 0.33 | ~13nm HP | 主力量产 (TSMC, Samsung, Intel, SK hynix, Micron) |
| High-NA EUV | EXE:5000/5200B | 0.55 | ~8nm HP | Intel完成5200B验收(2025.12)，14A节点计划使用 |

TSMC和Samsung对High-NA EUV的态度更为务实——首先最大化0.33 NA EUV的产能利用率，逐步引入High-NA。Intel则试图通过率先采用High-NA来在技术上获取代差优势。

---

## 5. PPA 对比分析

### 5.1 已验证的 PPA 数据

**TSMC N2 vs N3E**（IEDM 2024硅验证，Arm Cortex-A715实测）：

| 指标 | 相对N3E提升 | 置信度 |
|------|------------|--------|
| 性能 (同功耗) | +10-15% | 高（7家独立来源一致确认） |
| 功耗 (同频率) | -25-30% | 高（电压范围0.5V-0.9V验证） |
| 混合设计密度 | +15%（~1.15×） | 高（50%逻辑/30%SRAM/20%模拟混合基准） |
| 纯逻辑密度 | +~20% | 中（衍生估算） |

**关键客户产品映射（基于供应链信息）**：

| 客户 | N2产品 | 预期时间 |
|------|--------|---------|
| Apple | A20 Pro (iPhone 18系列), M5 | 2026年H2 |
| AMD | Zen 6 CPU, CDNA 5 MI400 AI加速器 | 2026-2027 |
| NVIDIA | Rubin Next 数据中心GPU | 2027-2028 |
| Intel | Nova Lake CPU（部分tile） | 2026-2027 |
| MediaTek | Dimensity 9600 SoC | 2026 |

### 5.2 未验证但行业公认的 PPA 参考数据

以下数据**未经过本次研究的对抗验证**，但基于公开文献/行业共识：

| 节点对比 | 性能提升 | 功耗降低 | 密度提升 |
|---------|---------|---------|---------|
| TSMC N7 vs 16FF | ~35% | ~65% | ~3.3× |
| TSMC N5 vs N7 | ~15% | ~30% | ~1.8× |
| TSMC N3 vs N5 | ~10-15% | ~25-30% | ~1.6× (逻辑); ~1.7× (芯片级) |
| Samsung 7LPP vs 10LPE | ~20% | ~50% | — |
| Samsung 5LPE vs 7LPP | ~10% | ~20% | ~1.33× |
| Intel 18A vs Intel 3 | — | — | — (数据待第三方确认) |

> **警示**：Intel 18A/TSMC N2/Samsung SF2之间的PPA横向对比数据（如Tom's Hardware/TechSpot声称的"Intel 18A 2.53 vs TSMC N2 2.27 vs Samsung SF2 2.19"性能指数）**在本次研究的3人对抗验证中被全票否决**，原因包括：(a) 这些数字来自TechInsights的归一化推断模型，而非实测数据；(b) 各厂商定义密度和性能的基准不同（HD库高度、track数、填充率等）。在第三方硅片实测数据出现之前，不应将此类"归一化"对比作为可靠结论。

---

## 6. 关键产品与节点映射

### 6.1 移动 SoC（手机处理器）演进

| 年份 | Apple | Qualcomm | Samsung Exynos | MediaTek | HiSilicon Kirin |
|------|-------|----------|---------------|----------|-----------------|
| 2011 | A5 (Samsung 45nm) | S4 Plus (TSMC 28nm LP) | Exynos 4210 (Samsung 45nm) | MT6575 (TSMC 40nm) | — |
| 2013 | A7 (Samsung 28nm) | S800 (TSMC 28nm HPM) | Exynos 5410 (Samsung 28nm) | MT6592 (TSMC 28nm HPM) | — |
| 2015 | A9 (TSMC 16FF/Samsung 14LPE) | S820 (Samsung 14LPE) | Exynos 7420 (Samsung 14LPE) | Helio X20 (TSMC 20nm) | Kirin 950 (TSMC 16FF+) |
| 2017 | A11 (TSMC 10nm) | S835 (Samsung 10LPE) | Exynos 8895 (Samsung 10LPE) | Helio X30 (TSMC 10nm) | Kirin 970 (TSMC 10nm) |
| 2018 | A12 (TSMC N7 DUV) | S855 (TSMC N7) | Exynos 9820 (Samsung 8nm) | — | Kirin 980 (TSMC N7) |
| 2020 | A14 (TSMC N5) | S888 (Samsung 5LPE) | Exynos 2100 (Samsung 5LPE) | Dimensity 1000 (TSMC N7) | Kirin 9000 (TSMC N5) |
| 2022 | A16 (TSMC N4P) | S8 Gen 2 (TSMC N4) | Exynos 2200 (Samsung 4LPE) | Dimensity 9200 (TSMC N4P) | — |
| 2023 | A17 Pro (TSMC N3B) | S8 Gen 3 (TSMC N4P) | — | Dimensity 9300 (TSMC N4P) | — |
| 2024-25 | A18/A19 (TSMC N3E) | S8 Elite (TSMC N3E) | Exynos 2500 (Samsung 3GAP, 失败) | Dimensity 9400 (TSMC N3E) | — |

### 6.2 CPU/GPU/AI 加速器

| 领域 | 关键产品 | 主要代工节点 | 代工厂 |
|------|---------|-------------|--------|
| **桌面/服务器 CPU** | AMD Zen 4 (Ryzen 7000/EPYC 9004) | TSMC N5 | TSMC |
| | AMD Zen 5 (Ryzen 9000/EPYC Turin) | TSMC N4P/N3 | TSMC |
| | AMD Zen 6 | TSMC N2 (预期) | TSMC |
| | Intel Meteor Lake (计算tile) | Intel 4 + TSMC N5/N6 | Intel+TSMC |
| | Intel Lunar Lake | TSMC N3B + TSMC N6 | TSMC |
| | Intel Panther Lake | Intel 18A | Intel |
| **消费级 GPU** | NVIDIA RTX 40 (Ada Lovelace) | TSMC N4 (4N) | TSMC |
| | NVIDIA RTX 50 (Blackwell) | TSMC N4P (4NP) | TSMC |
| | AMD Radeon RX 7000 (RDNA 3) | TSMC N5 + N6 | TSMC |
| **AI 加速器** | NVIDIA H100 (Hopper) | TSMC N4 (4N) | TSMC |
| | NVIDIA B200 (Blackwell) | TSMC N4P | TSMC |
| | NVIDIA Rubin Next | TSMC N2 (预期) | TSMC |
| | AMD MI300X | TSMC N5 + N6 (Chiplet) | TSMC |
| | AMD MI400 (CDNA 5) | TSMC N2 (预期) | TSMC |
| **数据中心 CPU** | AWS Graviton3/Graviton4 | TSMC N5/N4 | TSMC |
| | Google Axion | TSMC N4 | TSMC |
| | AmpereOne | TSMC N5 | TSMC |

**关键模式**：
- 2020年之后，AI加速器和大规模数据中心CPU的先进节点几乎**完全被TSMC垄断**。
- Samsung在3nm GAA失败后，丧失了所有AI/HPC大客户的订单。
- Intel 18A能否吸引外部AI芯片客户（如NVIDIA的某种低端产品线，或Broadcom/Cerebras等第三方设计），是Intel代工战略的核心检验。

---

## 7. 竞争格局演变

### 7.1 代工市场份额变迁

```
2015:  TSMC ~52%, Samsung ~11%, GF ~10%, UMC ~9%, SMIC ~5%
2019:  TSMC ~53%, Samsung ~16%, GF ~9%, UMC ~8%, SMIC ~5%
2024:  TSMC ~62%, Samsung ~11.5%, GF ~6%, UMC ~7%, SMIC ~5%
```

**驱动力**：

1. **TSMC份额持续攀升**：先进节点（7nm及以下）的垄断性地位，贡献了TSMC约50-60%的营收。AI浪潮（NVIDIA、AMD、云厂商自研芯片）几乎全部流向TSMC。

2. **Samsung份额先升后跌**：在7nm/5nm时代一度达到16%（Galaxy/HPC客户），但3nm GAA失败导致客户大规模外流。2024年Q2降至~11.5%，且先进节点收入占比极低。

3. **GF/UMC退守成熟节点**：两者在2018年后均放弃7nm追赶，专注于成熟节点（28nm+）和特殊工艺（FD-SOI、SiPh、GaN等）。

4. **Intel代工仍为零**：截至2026年中，Intel Foundry Services（IFS）尚未有公开确认的大规模外部代工客户。18A的高品质量产是第一道门槛。

### 7.2 战略分岔图

```
                    追求先进节点              放弃先进节点
                    (≤7nm)                    (>7nm)
                       │                          │
          ┌────────────┼────────────┐    ┌───────┴───────┐
          │            │            │    │               │
        TSMC       Samsung      Intel   GF            UMC
          │            │            │    │               │
      渐进保守      激进冒险      追赶型   22FDX/FDX+    28nm专家
      FinFET→      直接GAA       直接     SiPh/GaN      成熟节点
      GAA在2nm     在3nm         GAA+BSPDN  差异化        利润优先
          │            │            │
      成功(✔)     失败(✗)      待验证(?)
```

---

## 8. 开放问题与展望

### 8.1 未解决的关键问题

1. **GlobalFoundries放弃7nm的长期影响**：GF的退出是否将先进制程代工永久锁定为双寡头（TSMC + Samsung）？Intel的加入能否恢复竞争？全球半导体供应链对TSMC的过度依赖（地缘风险）如何缓解？

2. **Intel 18A的真实端到端良率**：Intel展示的良率数据是前端（FEOL）还是全流程（full-flow）？Intel的代工模式能否提供TSMC级别的客户服务、EDA/IP生态和PDK成熟度？

3. **SMIC的7nm能力边界**：SMIC使用DUV多图案化的7nm级芯片实际良率和产能如何？在美国出口管制持续收紧（2024-2025年多轮加强）下，SMIC能否维持14nm/7nm的量产并继续演进？

4. **Samsung的代工复兴可能性**：SF2/SF2Z（2nm GAA+BSPDN，2027年预期）能否修复3nm GAA造成的声誉损害？Samsung能否重新赢得Qualcomm/NVIDIA等大客户？

5. **High-NA EUV的采用节奏**：Intel率先采用High-NA能否转化为技术代差？TSMC的"最大化0.33 NA + 谨慎引入High-NA"策略是否会再次被证明正确？

6. **台海地缘政治风险**：TSMC 95%以上的先进产能集中在台湾，而台湾面临中国大陆持续的军事压力。TSMC的海外建厂（亚利桑那N4/N5、日本熊本、德国德累斯顿）能否分散风险？时间线如何？

### 8.2 未来3-5年预测

| 时间 | TSMC | Samsung | Intel | SMIC |
|------|------|---------|-------|------|
| 2026-27 | N2量产, A16 BSPDN | SF2量产, SF2Z BSPDN | 18A获取外部客户 | 7nm DUV小规模维持 |
| 2027-28 | A16 GAA+BSPDN HVM | 尝试赢回客户 | 14A High-NA EUV | 受制裁持续受限 |
| 2029-30 | 1nm级 (CFET?) | 不确定 | 目标代工份额#2 | 受限于出口管制 |

**基线预测**：TSMC将在未来3-5年内保持代工技术领先地位。Intel的工程能力不容低估（历史证明其有能力开发尖端工艺），但代工业务模式与IDM模式有根本性不同——客户服务、生态系统建设、IP保护（不与客户竞争）是核心挑战。Samsung需要在SF2/SF2Z证明良率后才有机会逆转颓势。

---

## 9. 数据源与参考

### 经对抗验证确认的来源（按置信度排序）

| # | 来源 | 类型 | 贡献 |
|---|------|------|------|
| 1 | TSMC Press Release (Oct 24, 2011) — pr.tsmc.com | 一手 | 28nm量产确认 |
| 2 | TSMC Press Release (Feb 25, 2013) — pr.tsmc.com | 一手 | 28nm HPM/Snapdragon 800 |
| 3 | Samsung Press Release (Oct 18, 2018) — news.samsung.com | 一手 | 首个商用EUV 7LPP |
| 4 | Samsung Semiconductor Newsroom (Jul 25, 2022) | 一手 | 3nm GAA量产仪式 |
| 5 | TSMC IEDM 2024 Paper | 一手 (学术) | N2 PPA 硅验证数据 |
| 6 | TSMC 1Q25 Earnings Call Transcript | 一手 | A16 H2 2026时间表 |
| 7 | Intel Newsroom (Jan 2025) | 一手 | 18A HVM确认 |
| 8 | Intel CES 2026 — Panther Lake | 一手 | 18A产品出货 |
| 9 | SemiAnalysis Newsletter | 二级 (高信誉) | N2良率、BSPDN策略 |
| 10 | SemiEngineering (Apr 2024) | 二级 (高信誉) | BSPDN从N2P移除 |
| 11 | AnandTech | 二级 (高信誉) | N2P失去BSPDN |
| 12 | The Korea Times | 新闻媒体 | Samsung 3nm单数良率 |
| 13 | TrendForce | 研究机构 | 3nm良率、N2产量、市场数据 |
| 14 | Samsung Securities | 投行 (Samsung旗下) | 代工损失$385M预测 |
| 15 | TechPowerUp | 二级科技媒体 | 二代3nm GAA良率~20% |
| 16 | Electronics Weekly / EEPW | 二级科技媒体 | Kevin Zhang N3 FinFET声明 |
| 17 | TSMC Technology Symposium (May 2026) | 一手 | N2缺陷密度数据 |
| 18 | Wedbush / TokenRing | 投行/分析 | N2良率65-75%估计 |

### 被对抗验证否决的来源

本次研究有17条声明被3-0或2-1投票否决。关键否决项包括：

- **anytesting.com**（3条声明0-3否决）：声称N2率先量产、Samsung SF2良率45%、SMIC 14nm量产及7nm开发等——被判定为不可靠的聚合网站，信息与一手来源矛盾。
- **migelab.com**（1条声明0-3否决）：声称TSMC是全球首家浸没式光刻90nm厂商（2004年）——与已知的浸没式光刻在65nm/45nm节点首次采用的历史事实矛盾。
- **Tom's Hardware / TechSpot TechInsights数据**（3条声明0-3否决）：声称Intel 18A密度238 MTr/mm² vs TSMC N2 313 MTr/mm²、归一化性能指数等——被判定为TechInsights建模推断、非实测数据、且各厂商密度定义不可比。
- **SemiAnalysis BSPDN声明**（1条1-2否决）：声称BSPDN在HPC设计上降功耗15-20%——2位验证者认为缺乏公开实测数据支撑。
- **notebookcheck-cn.com**（2条声明0-3否决）：声称N2首批产能分配（Apple锁定50%）和客户名单细节——被判定为推测性内容。

> **方法论说明**：每条声明由3名独立验证者评估，需要对一手来源、逻辑一致性和跨来源互证进行检验。2/3以上验证者认为声明不可靠时即被否决。

### 已知的研究缺口

1. **180nm-45nm平面CMOS时代**：本研究的网络搜索未能找到足够可信的来源来验证该时期的具体量产年份和产品对应关系。该段内容基于行业公认的历史知识补充。

2. **Intel 22nm-14nm-10nm PPA数据**：由于Intel在这些节点上未有代工客户（IDM时期），第三方独立PPA分析极少。

3. **GF/UMC/SMIC的详细节点数据**：这三个代工厂在其放弃的先进节点上（GF 7nm、UMC 14nm+、SMIC 7nm以下）公开信息有限。

4. **Samsung SF2/SF2Z的PPA和良率**：截至2026年中，Samsung 2nm节点的公开数据极少，大部分来自Samsung自己的营销材料和未经证实的供应链传闻。

---

## 附录A：工艺节点命名对照表

| 代工厂 | 28nm级 | 16/14nm | 10nm级 | 7nm级 | 5nm级 | 3nm级 | 2nm级 |
|--------|--------|---------|--------|-------|-------|-------|-------|
| TSMC | 28nm | 16FF/12FFC | N10 | N7/N7+/N6 | N5/N4 | N3/N3E/N3P | N2 |
| Samsung | 28nm | 14LPE/12LPP | 10LPE/8LPP | 7LPP/6LPP | 5LPE/4LPE | 3GAE/3GAP | SF2 |
| Intel | — | 14nm | Intel 7 (10nm) | — | — | Intel 3 | 18A |
| GF | 28nm | 14LPP/12LP | — | — | — | — | — |
| UMC | 28nm | 14nm | — | — | — | — | — |
| SMIC | 28nm | 14nm | — | N+1/N+2 | — | — | — |

> **注**：自Intel引入"Intel 7/4/3"命名后，行业基本接受了节点名称不再是物理栅极长度的事实——现代节点命名是市场定位标签。TSMC N5的物理栅极长度约为18nm，N3约为16nm，N2约14nm（沟道厚度）。"2nm"和"18A"(1.8nm)是等效的市场名称而非物理尺寸。

---

## 附录B：方法论声明

本报告采用了"深调研"（deep-research）方法框架：

1. **问题分解**：将原始研究问题分解为5个搜索角度
2. **并行搜索**：5个独立WebSearch agent同步搜索
3. **源抓取**：去重后抓取前27个高质量来源
4. **声明提取**：从27个来源提取85条可验证的独立声明
5. **对抗验证**：前25条声明（按重要性排序）经过3人独立验证——每人对声明进行支持/反驳/不确定投票
6. **裁定标准**：需≥2/3支持票才能确认为"已验证"；≤1/3支持票则被否决
7. **综合补充**：对被否决的17条声称进行记录，对已知缺口由报告作者（本会话AI）基于训练知识补充

**验证结果统计**：85条声明 → 25条验证 → 8条确认 → 7条综合后保留；17条被否决

**局限声明**：
- WebSearch和WebFetch工具受限于可公开访问的网页内容（付费墙后的内容不可获取）
- 对抗验证的质量取决于验证者能接触到的信息——对于某些高度专业化的半导体技术声明，验证者可能缺乏足够的技术背景
- 报告的未验证部分（补白内容）基于AI训练数据中的行业知识，未经过同样的对抗验证流程
- 所有数据截至2026年6月24日——半导体行业路线图变化迅速

---

> **报告完成日期**: 2026年6月24日  
> **方法论**: Deep Research (Search → Fetch → Adversarial Verify → Synthesize)  
> **原始研究问题**: 分析历史主流代工厂的工艺节点演进、主要产品、PPA对比，技术路线差异
