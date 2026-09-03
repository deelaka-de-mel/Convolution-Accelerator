# RISC-V Controlled Convolution Hardware Accelerator on FPGA

A hardware-accelerated image filtering system implemented on the **Terasic DE2-115 FPGA**, combining an open-source **PicoRV32 RISC-V processor** with a custom convolution accelerator and a shared-memory architecture.

The main objective is to investigate how a general-purpose processor and a dedicated hardware accelerator can work together while **minimizing memory transfers and improving overall system performance**.

---

## 📌 Project Overview

Modern processors can execute image-processing algorithms in software, but convolution is computationally intensive and contains a high degree of data-level parallelism. FPGAs can exploit this parallelism by implementing multiple arithmetic operations directly in hardware.

This project develops a heterogeneous FPGA system consisting of:

- **PicoRV32 RISC-V CPU** for general-purpose control and software execution
- **Custom convolution accelerator** for computationally intensive image filtering
- **Shared memory subsystem** accessible by both the CPU and accelerator
- **Memory-mapped control interface** for communication between the CPU and accelerator
- **DE2-115 FPGA** as the target hardware platform

The architecture is designed around the principle of keeping data close to the accelerator and avoiding unnecessary CPU ↔ accelerator memory transfers.

---

## 🎯 Project Objectives

The main objectives are:

1. Integrate the open-source **PicoRV32 RV32I processor** into the DE2-115 FPGA.
2. Develop a dedicated hardware accelerator for image convolution/filtering.
3. Design a shared-memory architecture that allows the CPU and accelerator to access common data.
4. Minimize unnecessary movement of image and kernel data between memories.
5. Develop a CPU-to-accelerator control interface.
6. Exploit FPGA parallelism to accelerate convolution operations.
7. Verify the hardware accelerator against a software reference implementation.
8. Compare the performance of software-based and hardware-accelerated convolution.
9. Evaluate the complete system primarily in terms of **system performance**.

---

# 🏗️ System Architecture

The proposed system consists of three major subsystems:

```text
                         ┌─────────────────────┐
                         │      PicoRV32       │
                         │     RISC-V CPU      │
                         │                     │
                         │  Control + Software │
                         └──────────┬──────────┘
                                    │
                              CPU Interface
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    │       Shared Memory           │
                    │                               │
                    │  ┌────────┐ ┌────────┐       │
                    │  │ Image  │ │ Kernel │       │
                    │  └────────┘ └────────┘       │
                    │                               │
                    │  ┌────────┐                   │
                    │  │ Output │                   │
                    │  └────────┘                   │
                    └───────────────┬───────────────┘
                                    │
                              Data Interface
                                    │
                         ┌──────────▼──────────┐
                         │ Convolution         │
                         │ Accelerator         │
                         │                     │
                         │ Line Buffers        │
                         │ Sliding Window      │
                         │ Multipliers / MACs  │
                         │ Adder Tree           │
                         │ Control FSM          │
                         └─────────────────────┘

                              DE2-115 FPGA
```

The CPU controls the accelerator through a set of memory-mapped registers, while the accelerator operates directly on data stored in shared memory.

---

# 🧠 Subsystem 1 — PicoRV32 RISC-V Processor

The processor subsystem uses **PicoRV32**, a size-optimized open-source RISC-V CPU.

### Responsibilities

- Integrate PicoRV32 into the Quartus project
- Configure the required PicoRV32 features
- Implement the CPU clock and reset infrastructure
- Connect the CPU to the system memory interface
- Implement the accelerator's memory-mapped control registers
- Develop firmware running on PicoRV32
- Configure accelerator operations from software
- Monitor accelerator status
- Retrieve and process accelerator results

### CPU Role

The CPU is **not responsible for performing every convolution operation**.

Instead, it acts primarily as the system controller:

```text
CPU
 │
 ├── Configure input/output addresses
 ├── Configure kernel information
 ├── Configure image dimensions
 ├── Start accelerator
 ├── Wait for completion
 └── Process/use results
```

This allows the computationally intensive convolution operation to be performed by dedicated FPGA hardware.

---

# ⚡ Subsystem 2 — Convolution Accelerator

The convolution accelerator performs the image-filtering operation in dedicated hardware.

For a 3×3 kernel, the basic operation is:

```text
                3×3 Image Window

             X0   X1   X2
             X3   X4   X5
             X6   X7   X8

              × Kernel

             K0   K1   K2
             K3   K4   K5
             K6   K7   K8

                    │
                    ▼

       X0K0 + X1K1 + ... + X8K8

                    │
                    ▼
               Output Pixel
```

Mathematically:

\[
Y(i,j)=\sum_{m=0}^{2}\sum_{n=0}^{2}
X(i+m,j+n)K(m,n)
\]

where:

- \(X\) is the input image
- \(K\) is the convolution kernel
- \(Y\) is the output image

### Accelerator Components

#### 1. Sliding Window

A hardware sliding-window mechanism supplies the convolution engine with the required neighboring pixels.

#### 2. Line Buffers

Line buffers retain previously received image rows so that the accelerator does not need to repeatedly fetch the same pixels from external/shared memory.

Conceptually:

```text
Input Image
     │
     ▼
┌─────────────┐
│ Line Buffer │
├─────────────┤
│ Line Buffer │
└──────┬──────┘
       │
       ▼
  3×3 Window
       │
       ▼
   MAC Engine
```

This is a key part of reducing memory traffic.

#### 3. Multipliers / MAC Units

The accelerator performs the pixel × kernel-weight operations in parallel or partially parallel depending on the selected architecture.

#### 4. Adder Tree

Partial multiplication results are combined using an adder tree to produce the convolution sum efficiently.

#### 5. Control FSM

The accelerator controls:

- Loading data
- Window generation
- MAC operations
- Output generation
- Moving to the next pixel
- Completion signalling

---

# 💾 Subsystem 3 — Shared Memory and Data Movement

A central requirement of the project is that the CPU and FPGA accelerator should work with a **common memory space**, minimizing unnecessary memory transfers.

The intended data flow is:

```text
                    Shared Memory
                 ┌─────────────────┐
                 │                 │
                 │ Input Image     │
                 │ Convolution     │
                 │ Kernel          │
                 │ Output Image    │
                 │                 │
                 └───────┬─────────┘
                         │
                  ┌──────┴──────┐
                  │             │
                  ▼             ▼
                CPU       Accelerator
```

Rather than following an inefficient approach such as:

```text
CPU Memory
    │
    ▼
Copy Image
    │
    ▼
Accelerator Memory
    │
    ▼
Process
    │
    ▼
Copy Result
    │
    ▼
CPU Memory
```

the project aims to enable:

```text
              Shared Memory
             ┌──────────────┐
             │ Input Image  │
             │ Kernel       │
             │ Output       │
             └──────┬───────┘
                    │
              ┌─────┴─────┐
              ▼           ▼
             CPU         FPGA
```

This reduces unnecessary data movement and can improve overall system performance.

### Memory Architecture

The exact implementation will be evaluated between possible architectures such as:

- Dual-port RAM
- Shared RAM with arbitration
- FPGA on-chip memory
- External DE2-115 memory with a suitable controller

The final implementation will be selected based on:

- Bandwidth
- Latency
- FPGA resource usage
- CPU/accelerator concurrency
- Overall system performance

---

# 🔌 CPU–Accelerator Interface

The accelerator will be controlled using a memory-mapped register interface.

A conceptual register map is:

| Address | Register | Description |
|---|---|---|
| `0x00` | `CONTROL` | Start/reset control |
| `0x04` | `STATUS` | Busy/done status |
| `0x08` | `INPUT_BASE` | Input image base address |
| `0x0C` | `KERNEL_BASE` | Kernel base address |
| `0x10` | `OUTPUT_BASE` | Output image base address |
| `0x14` | `IMAGE_WIDTH` | Image width |
| `0x18` | `IMAGE_HEIGHT` | Image height |
| `0x1C` | `KERNEL_SIZE` | Kernel dimensions |

The exact register map may be modified during implementation.

### Example Control Flow

```text
PicoRV32
   │
   ├── Write INPUT_BASE
   ├── Write KERNEL_BASE
   ├── Write OUTPUT_BASE
   ├── Write IMAGE_WIDTH
   ├── Write IMAGE_HEIGHT
   │
   ├── Write START
   │
   ▼
Convolution Accelerator
   │
   ├── Read image data
   ├── Perform convolution
   ├── Write output data
   │
   ▼
DONE
   │
   ▼
PicoRV32 continues execution
```

---

# 🖼️ Data Format

The initial implementation targets:

- **Input image:** 8-bit unsigned grayscale pixels
- **Kernel weights:** 8-bit signed values
- **Convolution:** Signed arithmetic where required
- **Output:** Width determined by accumulator/output requirements

Careful bit-width selection is required to prevent overflow during multiplication and accumulation.

For example:

```text
8-bit pixel × 8-bit signed weight
              │
              ▼
       Wider intermediate
              │
              ▼
        Accumulator
              │
              ▼
        Output pixel
```

The final accumulator width will be selected based on the supported image and kernel ranges.

---

# 🚀 Hardware Acceleration Strategy

The project investigates how FPGA-specific parallelism can improve convolution performance.

Potential optimizations include:

### Parallel Multiplication

Multiple pixel × kernel operations can be performed simultaneously.

```text
X0 × K0 ─┐
X1 × K1 ─┤
X2 × K2 ─┤
X3 × K3 ─┤
X4 × K4 ─┤──► Adder Tree ─► Output
X5 × K5 ─┤
X6 × K6 ─┤
X7 × K7 ─┤
X8 × K8 ─┘
```

### Pipelining

The datapath can be divided into pipeline stages to increase throughput.

### Line Buffers

Line buffers reduce repeated memory accesses.

### Data Reuse

Pixels already loaded into the sliding window are reused for neighboring output pixels.

These techniques are particularly important because the project's performance evaluation considers the **complete system**, rather than only the raw convolution computation.

---

# 🧪 Verification Strategy

The accelerator will be verified against a software reference implementation.

```text
                 Test Image
                     │
            ┌────────┴────────┐
            │                 │
            ▼                 ▼
     Python/MATLAB         FPGA RTL
       Reference          Accelerator
            │                 │
            │                 │
            └────────┬────────┘
                     ▼
                  Compare
                     │
              ┌──────┴──────┐
              │             │
            Match        Mismatch
```

Verification will cover:

- Individual multiplication operations
- Accumulation correctness
- Sliding-window generation
- Boundary conditions
- Different image dimensions
- Different kernels
- CPU-to-accelerator control
- Memory reads/writes
- Complete end-to-end convolution

---

# 📊 Performance Evaluation

The system will primarily be evaluated based on **system performance**.

Important metrics include:

### Execution Time

Compare:

\[
T_{software}
\]

against:

\[
T_{accelerated}
\]

### Speedup

\[
Speedup =
\frac{T_{software}}
{T_{accelerated}}
\]

### Throughput

For image processing:

\[
Throughput =
\frac{\text{Number of output pixels}}
{\text{Execution time}}
\]

### Memory Traffic

Measure the amount of data transferred between:

- CPU
- Memory
- Accelerator

A major objective is to reduce unnecessary transfers.

### FPGA Resource Utilization

The implementation can also be evaluated using:

- Logic elements
- Registers
- Embedded memory bits
- DSP blocks
- Maximum operating frequency

### Power / Energy

If measurement infrastructure permits, power consumption can also be compared between software and hardware-accelerated implementations.

---

# 👥 Technical Work Distribution

The project is divided into three major technical areas.

## Member 1 — PicoRV32 & CPU/Software Subsystem

Responsible for:

- PicoRV32 architecture study
- PicoRV32 integration
- Quartus implementation
- CPU clock/reset
- CPU memory interface
- Memory-mapped accelerator registers
- RISC-V firmware
- CPU control of the accelerator
- CPU-side verification

### Main Question

> **How does the RISC-V processor control the accelerator?**

---

## Member 2 — Convolution Accelerator

Responsible for:

- Convolution datapath
- MAC architecture
- Multipliers
- Adder tree
- Sliding-window architecture
- Line buffers
- Pipeline design
- Accelerator FSM
- Arithmetic bit-width design
- RTL implementation
- Accelerator verification

### Main Question

> **How can convolution be performed efficiently using FPGA hardware?**

---

## Member 3 — Shared Memory & System Architecture

Responsible for:

- Shared-memory architecture
- Memory controller/interface
- CPU/accelerator memory access
- Memory arbitration where required
- Address mapping
- Memory bandwidth analysis
- Data movement optimization
- DE2-115 memory integration
- Complete system integration
- System-level performance analysis

### Main Question

> **How can data movement between the CPU, accelerator and memory be minimized?**

---

# 🛠️ Hardware & Software Tools

## Hardware

- **Terasic DE2-115 FPGA**
- Intel FPGA device
- FPGA on-chip memory / DE2-115 memory resources
- Optional peripherals for demonstration

## HDL

- SystemVerilog
- Verilog

## Processor

- PicoRV32
- RISC-V RV32I

## FPGA Development

- Intel Quartus Prime
- ModelSim / QuestaSim where applicable

## Verification / Reference

- Python
- NumPy
- MATLAB where required

---

# 📁 Proposed Repository Structure

```text
.
├── rtl/
│   ├── cpu/
│   │   └── picorv32.v
│   │
│   ├── accelerator/
│   │   ├── convolution_accelerator.sv
│   │   ├── mac_unit.sv
│   │   ├── line_buffer.sv
│   │   ├── sliding_window.sv
│   │   └── accelerator_fsm.sv
│   │
│   ├── memory/
│   │   ├── shared_memory.sv
│   │   └── memory_arbiter.sv
│   │
│   └── system/
│       └── top.sv
│
├── firmware/
│   ├── main.c
│   ├── linker.ld
│   └── startup.s
│
├── simulation/
│   ├── tb_convolution.sv
│   ├── tb_accelerator.sv
│   └── tb_system.sv
│
├── software_reference/
│   ├── convolution.py
│   └── test_vectors/
│
├── quartus/
│   └── [Quartus project files]
│
├── docs/
│   ├── architecture/
│   └── figures/
│
└── README.md
```

The exact structure may change as implementation progresses.

---

# 🔄 Complete System Operation

The intended operation is:

```text
1. FPGA is initialized
        │
        ▼
2. PicoRV32 starts executing firmware
        │
        ▼
3. Input image and kernel are placed in shared memory
        │
        ▼
4. CPU configures accelerator registers
        │
        ▼
5. CPU asserts START
        │
        ▼
6. Accelerator reads required data from shared memory
        │
        ▼
7. Line buffers generate sliding convolution windows
        │
        ▼
8. Parallel MAC datapath performs convolution
        │
        ▼
9. Output pixels are written back to shared memory
        │
        ▼
10. Accelerator asserts DONE
        │
        ▼
11. PicoRV32 continues execution
        │
        ▼
12. Output can be inspected/processed
```

---

# 📈 Planned Performance Comparison

The project will compare different implementations where practical:

| Implementation | Processing Location | Expected Characteristics |
|---|---|---|
| Software convolution | PicoRV32 | Low hardware complexity, higher execution time |
| Basic hardware convolution | FPGA | Faster computation |
| Optimized hardware convolution | FPGA | Parallelism + data reuse |
| Shared-memory accelerator | FPGA + CPU | Reduced data movement |
| Optimized system | CPU + FPGA | Target architecture |

The final comparison will be based on measured results rather than theoretical estimates.

---

# 🔬 Key Engineering Challenges

The project focuses on several important hardware-design problems:

### 1. CPU–Accelerator Communication

Designing a simple and reliable interface between a general-purpose processor and custom hardware.

### 2. Memory Bandwidth

Convolution can require a very large number of memory accesses. The system must maximize data reuse.

### 3. Parallelism vs. Resource Usage

More parallel MAC units can improve throughput but consume more FPGA resources.

### 4. Arithmetic Precision

Multiplication and accumulation require careful bit-width selection to avoid overflow while preventing unnecessary hardware usage.

### 5. CPU/Accelerator Concurrency

The shared-memory architecture must handle cases where both the CPU and accelerator request memory.

### 6. System-Level Performance

A faster convolution datapath does not necessarily result in a faster system if memory transfer and control overhead dominate execution time.

---

# 📌 Design Philosophy

The project is based on three principles:

### Compute Where It Is Most Efficient

Use the CPU for control and general-purpose tasks, and FPGA hardware for highly parallel convolution operations.

### Move Data as Little as Possible

Use shared memory, line buffers, and data reuse to reduce memory traffic.

### Optimize the Complete System

The objective is not simply to build the fastest MAC unit.

The important metric is:

\[
\boxed{\text{CPU + Memory + Accelerator + Communication}}
\]

as a complete system.

---

# 📍 Current Status

### Completed

- [x] Project architecture defined
- [x] PicoRV32 selected as the CPU
- [x] DE2-115 selected as the FPGA platform
- [x] Shared-memory accelerator concept defined
- [x] Three-subsystem technical architecture defined

### In Progress

- [ ] PicoRV32 Quartus integration
- [ ] CPU memory interface
- [ ] Shared-memory implementation
- [ ] Accelerator control interface
- [ ] Convolution RTL
- [ ] Sliding-window / line-buffer implementation
- [ ] RISC-V firmware
- [ ] RTL simulation
- [ ] FPGA implementation
- [ ] Performance benchmarking

### Planned

- [ ] Full CPU + accelerator integration
- [ ] End-to-end image filtering
- [ ] Hardware/software comparison
- [ ] Resource utilization analysis
- [ ] Memory-bandwidth analysis
- [ ] Performance optimization

---

# 📚 References

- **PicoRV32** — Clifford Wolf's size-optimized RISC-V CPU
- **RISC-V ISA** — RISC-V Instruction Set Architecture specifications
- **Intel Quartus Prime** — FPGA development and synthesis environment
- **Terasic DE2-115** — FPGA development board documentation

---

## 👨‍💻 Project

**Project:** Domain Accelerator — FPGA Convolution Hardware Accelerator  
**Platform:** Terasic DE2-115  
**Processor:** PicoRV32 / RISC-V  
**HDL:** SystemVerilog / Verilog  
**Application:** Image Convolution / Filtering  
**Architecture:** CPU + Shared Memory + Hardware Accelerator

> **Goal:** Build a complete heterogeneous CPU–FPGA system that accelerates image convolution while minimizing memory movement and maximizing overall system performance.
