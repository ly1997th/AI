# ALPhA-Vision: A Real-Time Always-On Vision Processor with 787μs Face Detection Latency in <5mW

**Authors:** Ben Keller¹, Rangharajan Venkatesan¹, Steve Dai¹, Jason Clemons², Matthew Fojtik², Muya Chang¹, Thierry Tambe¹⁴, Nathaniel Pinckney¹, Stephen G. Tell², Qijing Huang¹, Shalini De Mello¹, Brucek Khailany²

> ¹ NVIDIA, Santa Clara, CA &emsp; ² NVIDIA, Austin, TX &emsp; ³ NVIDIA, Durham, NC &emsp; ⁴ Stanford University, Stanford, CA

**Published at:** ISSCC 2026 / Session 31 / AI Accelerators / Paper 31.9
Digest of Technical Papers, pp. 548–550 &emsp; © 2026 IEEE

---

## Abstract

ALPhA-Vision is an always-on low-power subsystem for DNN-inference-based vision tasks in edge SoCs. Flexible and programmable, the subsystem supports CNN and ViT inference and employs hardware/software co-design to enable fully end-to-end execution with **no external memory accesses**. Fine-grained power management features to mitigate leakage enable the subsystem to perform face detection with **787μs latency** and **99.3% detection accuracy** with **4.6mW average power at 60fps**.

---

## I. Introduction & Motivation

Always-on computer vision (CV) tasks are key workloads in applications such as user presence detection, safety monitoring, and gesture-based control, with always-on vision (AoV) poised to become even more prevalent as embodied artificial intelligence enters the mainstream [1]. In consumer devices, use cases such as face detection for opportunistic laptop display sleep can enable significant system-level power savings if a low-latency vision pipeline can be continuously executed in a low power footprint. Typical vision pipelines include both deep neural network (DNN) inference tasks and classical CV kernels, requiring a flexible and capable platform for end-to-end execution. GPU-based edge SoCs can execute these workloads, but their high power consumption (~10W) limits their utility for AoV applications [2].

This work presents **ALPhA-Vision** (Always-on Low-Power Accelerator for Vision), a dedicated subsystem for larger high-performance SoCs that enables the rest of the SoC to sleep while the standalone subsystem runs continuously in a low power footprint (see Fig. 31.9.1). The programmable subsystem supports a variety of DNN inference workloads, including both **convolutional neural networks (CNNs)** and **vision transformers (ViTs)**. Specialized hardware accelerates not only matrix multiplication (GEMM) kernels, but many other layer types commonly found in CV DNNs, ensuring that non-GEMM operations do not bottleneck low-latency execution. Aggressive quantization and a capacity-maximizing hardware implementation enable end-to-end localized processing of image inputs without accessing external memory. Hardware-software codesign for fine-grained power management enables a sub-5mW power budget even at high framerates. A companion full-stack compiler flow lowers application source code to execution binaries after performing hardware-compliant quantization-aware training (QAT) to maintain task accuracy. Together, these components enable end-to-end execution of AoV pipelines without waking the high-power CPU, GPU, or main memory system of the full SoC.

---

## II. Architecture & Design Overview

Figure 31.9.2 shows the ALPhA-Vision architecture, which comprises:

| Component | Description |
|-----------|-------------|
| **DLA** (Deep-Learning Accelerator) | Executes GEMMs |
| **NMP** (Near-Memory Processor) | Dedicated to low-compute-intensity kernels |
| **RV** (32b RISC-V Rocket) [3] | System controller |
| **Global Memory System** | 2.125MB SRAM for fully resident weights and activations |

Unlike prior works that target ultra-low-power edge devices using specialized low-leakage processes [4–10], ALPhA-Vision is designed as a subsystem for a larger SoC and therefore uses a standard high-performance process. Accordingly, SRAM leakage is a large component of overall power consumption, and minimizing this leakage power was a **first-class consideration** for system design. The most important factor in reducing static power consumption is for the system to **"race to sleep"** so it can spend as much time as possible in a low-power sleep mode. To accomplish this, compute units are optimized to target sub-ms end-to-end latency for typical workloads so that the system can sleep for most of each frame, even in high-framerate (60fps) scenarios.

### A. Deep Learning Accelerator (DLA)

The ALPhA-Vision DLA accelerates convolution and GEMM kernels that make up the bulk of DNN compute. The DLA supports both **INT8** and **INT4 with microscaling** (INT8 scale factors with a block size of 32) [11,12] math operations, performing matrix-vector multiplication in 32 parallel lanes of 32-element vector MACs (16 for INT8) each cycle, for a total of **1024 MACs/cycle** (512 for INT8) when fully utilized. Weights and activations are initially stored in global memory, with local buffers, collectors, and address generators orchestrating an efficient **output-stationary, local-weight-stationary dataflow** to maximize reuse [13], while affording high utilization on a range of different GEMM shapes. A post-processing unit (PPU) performs bias addition, scaling, and simple activation operations, such as ReLU and Tanh.

### B. Near-Memory Processor (NMP)

The compute acceleration afforded by the DLA is not sufficient to realize low latency on end-to-end DNN inference workloads, as a **"long tail" of operations with low compute intensity** would dominate the remaining runtime. The NMP, a programmable vector engine with high (128B/cycle) bandwidth to global memory, accelerates these remaining workloads:

| NMP Capability | Details |
|---------------|---------|
| DWConv | Specialized engine, 32 MACs/cycle |
| Non-GEMM Ops | GroupNorm, SoftMax |
| Elementwise Ops | Add, multiply, etc. |
| Memory Ops | Shuffle, transpose |
| Perspective Warp | Dedicated engine for classical CV |
| Precision | All operations in INT8 |

### C. Global Memory System

The global memories were co-designed with the accelerators to avoid memory-induced bottlenecks while maximizing capacity:

| Memory | Banks | Read BW | Write BW | Stores |
|--------|-------|---------|----------|--------|
| **GWM** (Global Weight Memory) | 16 | 68B/cycle | — | Most weights |
| **GS** (Global Scratchpad) | 64 | 136B/cycle | 65B/cycle | Input image, activations, DWConv weights, RV program |

The high GS bank count enables fine-grained memory management and supports multiple parallel accesses to different banks, with 14 physical banks statically grouped into virtual bank clusters for higher bandwidth. Virtual-to-physical address translation is hardware managed by accelerator address generators at runtime and can be reconfigured per DNN layer. The global memories minimize large, expensive crossbar structures by a compiler-enforced requirement that each bank be reserved for access by at most one requestor at a time.

---

## III. Power Management Innovations

The ALPhA-Vision design minimizes static power—the dominant component of energy per frame—both through direct optimization and by minimizing active-mode latency to maximize the time the subsystem is in sleep mode (see Fig. 31.9.3).

### Key Power-Saving Features

**1. Fine-grained SRAM sleep states:**
- Each GWM/GS bank independently placed into **retention** (power-gated periphery) or **sleep** (power-gated macros) modes
- Settings adjustable on-the-fly during active-mode execution [14]
- Retention mode: ~3× leakage reduction vs. active
- Sleep mode: ~100× leakage reduction vs. active

**2. Clock gating (CG):**
- Hardware-managed leaf-level clock gating
- Software-controlled block-level CG for DLA and NMP
- Software-programmable **root CG**: halts the entire clock distribution network, leaving only a single 31b counter active as a restart timer

**3. HVT standard cells** favored (outside of clock trees) to minimize leakage

**4. Deep configuration memories** in DLA and NMP: enables up to **384 kernels fused** and executed back-to-back with no RV intervention

**5. RISC-V double-clock execution mode:** RV clock runs at 2× the system frequency with zero-cycle clock domain crossing latency between the 2× and 1× domains

---

## IV. Software Flow & Compilation

Figure 31.9.4 provides an overview of the application software flow:

1. **PyTorch** application software → per-layer quantization configuration
2. Configuration accounts for hardware constraints and accuracy maintenance
3. **QAT** yields quantized per-layer weights, biases, and scaling factors
4. Software stack allocates memory in GWM and GS, tracking activation **liveness**
5. **Timeloop** [15] maps each GEMM onto the DLA, selecting loop nest dimensions for max utilization
6. Quantized layers are **fused** into execution kernels

Using this flow, the weight and peak activation memory footprints of **Yolov5n-0.5** [16] are reduced to **318KB** and **461KB**, respectively, while maintaining task accuracy—enabling fully on-chip execution with no external memory accesses.

---

## V. Measurement Results

A standalone testchip prototype was taped out in **16nm** with an active area of **4.20mm²**. The testchip operates at **359MHz at 0.6V** (RV at 718MHz)—a moderate clock period that minimizes LVT cell swaps and gate upsizing while minimizing latency for race-to-sleep.

### Face Detection (Yolov5n on WiderFace [19], 192×192 grayscale input)

| Metric | Value |
|--------|-------|
| Face detection latency | **787μs** |
| Peak throughput | 1270fps |
| Sleep time per frame (60fps) | **95.3%** |
| Detection accuracy | **99.3%** (WiderFace), 95.9% (FDDB [22]) |
| Average power at 60fps | **4.6mW** |
| Leakage floor (clocks off, all SRAM sleep) | 1.8mW |

### Runtime Breakdown (1 frame)
- Non-GEMM operations: only **21%** of active cycles—accelerators effectively mitigate compute bottlenecks

### Power-Saving Benefits
- Active energy savings: **21%** (10% from partitioning into multiple kernels for fine-grained SRAM sleep state reprogramming)
- Sleep energy savings: **94%**

### Cross-Workload Utilization (MobileVitv2 [20], Yolov5, perspective warp)
- DLA average compute utilization: **81%**
- NMP average bandwidth utilization: **86%**

---

## VI. Comparison to Prior Works

Figure 31.9.6 shows comparison to prior works [7,17,18,23,24]:

| Metric | This Work | Prior Works |
|--------|-----------|-------------|
| Frequency | 359MHz @ 0.6V | 90–830MHz |
| Active Power | 3.9–11.51mW | 0.62–12.779mW |
| Average Power (60fps) | **4.6mW** | — |
| On-chip SRAM | **1.798MB** | 0.125–1.176MB |
| Throughput | 1465 GOPS¹ | up to 2250 GOPS |
| Energy Efficiency | **16.3 TOPS/W** (4b) | 1.19–5778 TOPS/W |
| Fully On-Chip End-to-End | **Yes** | No |

> ¹ 1 MAC = 2 ops, other ops ignored. DLA peak: 295 TOPS/W. Comparisons use varied workloads—see paper for details.

---

## VII. Conclusion

ALPhA-Vision demonstrates that a programmable, flexible always-on vision subsystem can achieve sub-millisecond face detection latency (787μs) with 99.3% accuracy at 4.6mW average power.

### Five Key Innovations

1. **End-to-end on-chip execution** with no external memory accesses
2. **DLA + NMP heterogeneous compute** covering both GEMM and non-GEMM operations
3. **Fine-grained SRAM power gating** for aggressive leakage reduction
4. **"Race-to-sleep" strategy** minimizing active-mode duty cycle
5. **Full-stack compiler flow** with hardware-compliant QAT

The measurement results demonstrate that ALPhA-Vision can enable always-on vision applications in power-constrained edge devices, providing **>2000× power reduction** compared to GPU-based solutions (~10W → ~4.6mW).

---

## Chip Photo & Area Breakdown

| Metric | Value |
|--------|-------|
| Die Area | 1.452mm × 2.891mm = **4.20mm²** |
| Process | 16nm CMOS |

**Key blocks:** Global Weight Memory (GWM, 16 banks) · Global Scratchpad (GS, 64 banks) · DLA (32-lane vector MAC array) · NMP (Vector engine + DWConv engine) · RISC-V Rocket Processor (RV, 32-bit) · Test logic, routing & utilities

---

## Acknowledgement

The authors would like to thank Miguel Rodriguez, Amey Kulkarni, Sirisha Jayanti, Oliver Li, Walter Li, Vijayan Rathnam, Mike Sekulic, Tom Gray, and Tezaswi Raja for tapeout, package, and PCB support.

---

## References (Selected)

1. J. Duan et al., "A Survey of Embodied AI," *IEEE TETCI*, vol. 6, no. 2, 2022.
2. NVIDIA, Jetson Orin NX Module Datasheet.
3. K. Asanović et al., "The Rocket Chip Generator," Tech. Rep., UC Berkeley, 2016.
4. Z. Fan et al., "Audio and Image Cross-Modal Intelligence via a 10 TOPS/W 22nm SoC," *IEEE Symp. VLSI Circuits*, 2022.
5. V. Jain et al., "TinyVers: A 0.8–17 TOPS/W Tiny Versatile SoC," *IEEE Symp. VLSI Circuits*, 2022.
6. P. Jokic et al., "A Sub-mW Dual-Engine ML Inference SoC for Complete End-to-End Face-Analysis at the Edge," *IEEE Symp. VLSI Circuits*, 2021.
7. H. An et al., "A 170μW Image Signal Processor," *IEEE Symp. VLSI Circuits*, 2020.
8. I. Miro-Panades et al., "SamurAI: a 1.7MOPS–36GOPS Adaptive Versatile IoT Node," *IEEE Symp. VLSI Circuits*, 2020.
9. D. Garrett et al., "A 1mW Always-on Computer Vision Deep Learning Neural Decision Processor," *ISSCC*, 2023.
10. F. Conti et al., "A 12.4TOPS/W @ 136 GOPS AI-IoT SoC with 16 RISC-V," *ISSCC*, 2023.
11. S. Dai et al., "VS-Quant: Per-vector Scaled Quantization," *MLSys*, 2021.
12. B. D. Rouhani et al., "Microscaling Data Formats for Deep Learning," *arXiv:2310.10537*, 2023.
13. B. Keller et al., "A 95.6-TOPS/W Deep Learning Inference Accelerator With Per-Vector Scaled 4-bit Quantization in 5nm," *IEEE JSSC*, vol. 58, no. 4, 2023.
14. K. Prabhu et al., "MINOTAUR: A Posit-Based Edge Transformer Inference and Training Accelerator," *IEEE JSSC*, vol. 60, no. 4, 2025.
15. A. Parashar et al., "Timeloop: A Systematic Approach to DNN Accelerator Evaluation," *IEEE ISPASS*, 2019.
16. Q. Delong et al., "YOLO5Face: Why Reinventing a Face Detector," *arXiv:2105.12931*, 2021.
17. Z. Yuan et al., "A 65nm 24.7pJ/Frame 12.3mW Activation-Similarity-Aware CNN Video Processor," *ISSCC*, 2020.
18. S. Kwon et al., "Monolithic In-Memory Computing Microprocessor for End-to-End DNN Inferencing in MRAM-Embedded 28nm CMOS," *ISSCC*, 2025.
19. S. Yang et al., "WIDER FACE: A Face Detection Benchmark," *CVPR*, 2016.
20. S. Mehta and M. Rastegari, "Separable Self-attention for Mobile Vision Transformers," *TMLR*, 2023.
21. G. Fanelli et al., "Random Forests for Real Time 3D Face Analysis," *IJCV*, vol. 101, no. 3, 2013.
22. V. Jain and E. Learned-Miller, "FDDB: A Benchmark for Face Detection in Unconstrained Settings," UMass Amherst Tech. Rep., 2010.
23. A. Gupta et al., "CogniVision: End-to-End SoC for Always-on Smart Vision with mW Power in 40nm," *IEEE Symp. VLSI Circuits*, 2024.
24. E. Chang et al., "A 12-nm 0.62–1.61 mW Ultra-Low Power Digital CIM-based Deep-Learning System for End-to-End Always-on Vision," *IEEE Symp. VLSI Circuits*, 2023.

---

> © 2026 IEEE. Published in ISSCC 2026 Digest of Technical Papers, pp. 548–550. 979-8-3315-8936-3/26/\$31.00
