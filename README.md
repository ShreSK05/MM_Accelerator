# 4×4 Systolic Matrix Multiplication Accelerator (FPGA — Xilinx Vivado)

A hardware accelerator for 4×4 unsigned integer matrix multiplication, implemented in Verilog and targeted at Xilinx FPGAs using Vivado. The design uses a parallel MAC array with an FSM controller, completing one full matrix multiplication in 23 clock cycles compared to ~131 cycles for a serial implementation — a 5.7× speedup.

---

## Problem Statement

Matrix multiplication is the core operation in digital signal processing, neural network inference, image processing, and linear algebra workloads. On a general-purpose processor, computing C = A × B for two 4×4 matrices requires 16 output elements, each needing 4 multiplications and 3 additions — 112 arithmetic operations in total, executed one at a time.

For real-time and embedded applications running on FPGAs, this sequential bottleneck is unacceptable. The challenge is to design a synthesizable, pipelined hardware accelerator that:

- Computes all 16 output elements **simultaneously** using dedicated hardware
- Uses a proper **FSM** to sequence data loading, computation, and output
- Is **fully synthesizable** in Xilinx Vivado without SystemVerilog or unsupported constructs
- Handles **overflow** gracefully through unsigned saturation
- Produces verified, cycle-accurate results confirmed by simulation

---

## Solution

The design instantiates **16 MAC (Multiply-Accumulate) units** in parallel — one per output element C[i][j]. Each MAC unit independently computes:

```
C[i][j] = A[i][0]×B[0][j] + A[i][1]×B[1][j] + A[i][2]×B[2][j] + A[i][3]×B[3][j]
```

A central **k-counter** (0 → 3) selects which column of A and which row of B to feed each MAC unit on every compute cycle. The FSM sequences the operation through four states: IDLE → LOAD → COMPUTE → DONE.

### Architecture overview

```
          a_in_flat [255:0]          b_in_flat [255:0]
                 │                          │
         ┌───────▼──────────────────────────▼───────┐
         │           matrix_mult_top                 │
         │                                           │
         │   ┌─────────────┐   ┌──────────────────┐ │
         │   │ fsm_control │──▶│ systolic_array   │ │
         │   │ler          │   │ _4x4             │ │
         │   └─────────────┘   │                  │ │
         │                     │  ┌────┐ ┌────┐   │ │
         │                     │  │MAC │ │MAC │   │ │
         │                     │  └────┘ └────┘   │ │
         │                     │    ×16 units      │ │
         │                     └──────────────────┘ │
         └───────────────────────────────────────────┘
                        │                  │
               c_out_flat [511:0]        done
```

### MAC unit pipeline (2 stages)

```
Cycle N:    a × b  ──▶  product_r  (stage 1 register)
Cycle N+1:  result +=  product_r  (stage 2 accumulate)
```

Because of this 2-stage pipeline, the COMPUTE phase runs for **N + 1 = 5 cycles**: 4 cycles to feed all k values, plus 1 cycle to flush the final product from `product_r` into the accumulator.

---

## Timing Analysis

### FSM state durations

| State   | Cycles | Purpose |
|---------|--------|---------|
| IDLE    | 1      | Reset all accumulators, wait for `start` |
| LOAD    | 16     | N×N counter runs (data held on input bus) |
| COMPUTE | 5      | k-counter 0→3 feeds MAC units, +1 pipeline flush |
| DONE    | 1      | `done` asserted, output register latched |
| **Total** | **23** | **Per matrix multiplication** |

### Parallel vs serial comparison

| Metric | Parallel  | Serial equivalent |
|--------|----------------------|-------------------|
| Arithmetic ops | 5 cycles (all 16 outputs at once) | 112 cycles (7 ops × 16 outputs) |
| Load overhead | 16 cycles | 16 cycles |
| FSM overhead | 2 cycles | 3 cycles |
| **Total** | **23 cycles** | **~131 cycles** |
| **Speedup** | **5.7×** | — |

### Cycle-accurate waveform (COMPUTE phase)

```
         cy1      cy2      cy3      cy4      cy5
         ┌────────┬────────┬────────┬────────┬────────┐
k_cnt    │  k=0   │  k=1   │  k=2   │  k=3   │ (done) │
         ├────────┼────────┼────────┼────────┼────────┤
product_r│  p0    │  p1    │  p2    │  p3    │ flush  │  ← Stage 1
         ├────────┼────────┼────────┼────────┼────────┤
result   │   0    │  +p0   │  +p1   │  +p2   │  +p3   │  ← Stage 2
         └────────┴────────┴────────┴────────┴────────┘
                                              ▲
                                         VALID here
```

### Critical path

The critical path runs through the MAC unit's accumulator addition:

```
product_r register output
    → 33-bit zero-extend {1'b0, result}
    → 33-bit adder (sum_ext)
    → carry-out check (overflow)
    → multiplexer (saturate or sum)
    → result register input
```

This path determines the maximum achievable clock frequency. Run Vivado's timing analysis after implementation to find the exact Fmax for your target device.

---

## Project Files

```
📁 project root
│
├── mac_unit.v              MAC unit — 2-stage pipeline, unsigned saturating accumulator
├── systolic_array_4x4.v    16 MAC units with k-counter mux for A[i][k] and B[k][j]
├── fsm_controller.v        4-state FSM: IDLE → LOAD → COMPUTE → DONE
├── input_buffer.v          Dual-port synchronous RAM for matrix input storage
├── output_buffer.v         Synchronous RAM with overflow flag for result storage
├── matrix_mult_top.v       Top-level integrator — connects FSM + systolic array
├── tb_matrix_mult_top.v    Self-checking testbench with 5 test cases
└── README.md               This file
```

### File descriptions

**`mac_unit.v`**
Two-stage pipelined multiply-accumulate unit. Stage 1 registers the product `a × b`. Stage 2 adds it to the running accumulator. Overflow is detected using a 33-bit extended adder (carry-out = overflow). On overflow, the result saturates to `0xFFFF_FFFF` instead of wrapping. Parameters: `DATA_WIDTH` (default 16), `ACCUM_WIDTH` (default 32).

**`systolic_array_4x4.v`**
Instantiates 16 `mac_unit` modules in a 4×4 logical grid. A 2-bit `k_cnt` register increments each compute cycle, selecting column `k` of matrix A and row `k` of matrix B via combinational muxes. All MAC units receive their correct `A[i][k]` and `B[k][j]` inputs simultaneously. All ports use flat buses (no 2D array ports — Vivado compatible).

**`fsm_controller.v`**
Mealy/Moore FSM with a 5-bit load counter (counts to N×N − 1 = 15) and a 4-bit compute counter (counts to N = 4). Outputs: `load_data`, `compute_enable`, `clear_accum`, `done`, `cycle_count`.

**`input_buffer.v`**
Synchronous dual-port SRAM-style buffer, 16 locations × `DATA_WIDTH` bits. Write port: `write_enable`, `write_addr [3:0]`, `write_data`. Read port: `read_enable`, `read_addr [3:0]`, `read_data`. Reset clears all 16 locations explicitly (no integer loop — Vivado synthesizable).

**`output_buffer.v`**
Same structure as input buffer but stores `ACCUM_WIDTH`-wide results. Includes an `overflow_detected` sticky flag that sets on any saturated write and clears on read.

**`matrix_mult_top.v`**
Top-level module. Instantiates `fsm_controller` and `systolic_array_4x4`. Latches `c_out_flat` from the systolic array into an output register on the rising edge of `done`. All ports are flat buses for Vivado compatibility.

**`tb_matrix_mult_top.v`**
Self-checking testbench. Computes the expected result in software using integer arithmetic, then compares every element of `c_out_flat` against it. Prints PASS/FAIL per test. Five test cases:
1. Identity × Identity = Identity
2. All-ones → every element = 4
3. Ascending × Transpose (non-trivial values)
4. Zero matrix → all zeros
5. Constant matrices (A=2, B=3 → every element = 24)

---

## Inputs and Outputs

### Top-level port table (`matrix_mult_top`)

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock. All logic is synchronous to rising edge |
| `rst_n` | Input | 1 | Active-low asynchronous reset. Hold low for ≥2 cycles on power-up |
| `start` | Input | 1 | Pulse high for exactly **one clock cycle** to begin a multiplication |
| `a_in_flat` | Input | 256 | Matrix A packed as 16 × 16-bit unsigned integers |
| `b_in_flat` | Input | 256 | Matrix B packed as 16 × 16-bit unsigned integers |
| `c_out_flat` | Output | 512 | Result matrix C packed as 16 × 32-bit unsigned integers |
| `done` | Output | 1 | Goes high when result is valid. Stays high until `start` is pulsed again |
| `overflow_flag` | Output | 1 | High if any MAC unit saturated during the last computation |

### Matrix packing format

Elements are packed in row-major order. Element `[i][j]` (row i, column j) occupies bits:

```
// For a_in_flat and b_in_flat (16-bit elements):
a_in_flat[ (i*4 + j)*16  +:  16 ]  =  A[i][j]

// For c_out_flat (32-bit elements):
c_out_flat[ (i*4 + j)*32  +:  32 ]  =  C[i][j]
```

Example — packing matrix A in Verilog:

```verilog
// A = [[1, 2, 3, 4],
//      [5, 6, 7, 8],
//      [9,10,11,12],
//      [13,14,15,16]]

reg [255:0] a_in_flat;
integer i, j;
always @(*) begin
    for (i = 0; i < 4; i = i + 1)
        for (j = 0; j < 4; j = j + 1)
            a_in_flat[(i*4 + j)*16 +: 16] = A[i][j];
end
```

### Timing diagram — one complete run

```
clk      ___┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐
            └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

rst_n    ───────────┐
                    └──────────────────────────────────────

start    ──────┐    ┌──┐
               └────┘  └──────────────────────────────────

FSM      IDLE   IDLE  LOAD(×16)    COMPUTE(×5)   DONE  IDLE

done     ────────────────────────────────────┐   ┌──┐
                                             └───┘  └──────

c_out    ────────────────────────────────────┬─────────────
         (undefined / previous result)       │ VALID RESULT

Expected output:
```
TEST 1
  PASS — C[0][0]=1  C[1][1]=1  C[2][2]=1  C[3][3]=1
TEST 2
  PASS — C[0][0]=4  C[1][1]=4  C[2][2]=4  C[3][3]=4
TEST 3 
  PASS — C[0][0]=30  C[1][1]=174  C[2][2]=446  C[3][3]=846
TEST 4
  PASS — C[0][0]=0  C[1][1]=0  C[2][2]=0  C[3][3]=0
TEST 5 
  PASS — C[0][0]=24  C[1][1]=24  C[2][2]=24  C[3][3]=24


  PASSED : 5 / 5
  FAILED : 0 / 5



## Parameters

All key parameters are defined at the top of each module and can be overridden at instantiation:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 16 | Bit width of input matrix elements |
| `ACCUM_WIDTH` | 32 | Bit width of accumulator and output elements |
| `N` | 4 | Matrix dimension (N×N) |


