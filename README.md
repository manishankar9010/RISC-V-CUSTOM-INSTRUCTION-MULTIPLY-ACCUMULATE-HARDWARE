# RISC-V Custom Instruction — Multiply-Accumulate Hardware

A 5-stage pipelined RV32I processor in Verilog, extended with the RV32M multiply/divide unit and a **custom multiply-accumulate (MAC) instruction** implemented as dedicated hardware in the execute stage.

## Motivation

The RISC-V ISA reserves opcode space for custom instructions so that designers can accelerate application-specific workloads. In autonomous swarm drones, real-time collision avoidance and sensor fusion are dominated by dot-product-style arithmetic — repeated multiply-then-accumulate over vector operands. Executing that as a `MUL` followed by an `ADD` costs two instructions, two register-file writes, and two pipeline slots per term.

This project folds the operation into a single instruction backed by a hardware MAC unit with its own internal accumulator, so a dot product costs one instruction per term and the running sum never leaves the datapath.

## The custom MAC instruction

Encoded in the RISC-V **custom-0** opcode space, R-type format:

| Field | Value | Notes |
|-------|-------|-------|
| `opcode` | `7'b0001011` | custom-0 (0x0B) |
| `funct3` | `3'b000` | selects various modes |
| `funct7` | `7'b0000001` | selects various modes|
| `rs1` | operand A | lower 16 bits used, signed |
| `rs2` | operand B | lower 16 bits used, signed |
| `rd` | destination | receives the accumulator value |

**Operation:** `ACC ← saturate(ACC + signext(rs1[15:0]) × signext(rs2[15:0]))`, with the accumulator value written back to `rd`.

## MAC datapath

The MAC unit is a **two-stage pipeline** (2-cycle latency):

```
rs1[15:0] ─┐
           ├──► booth_multiplier ──► product[31:0] ──► accumulator_adder ──► accum_out[31:0]
rs2[15:0] ─┘    (radix-4 Booth +                       (saturating,              │
                 Dadda CSA tree)                        32-bit signed)      mac_overflow
```

- **Cycle T** (`en = 1`): `booth_multiplier` registers the 32-bit signed product.
- **Cycle T+1** (`en_d1 = 1`): `accumulator_adder` adds the product into the accumulator.

### `mac_unit` ports

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `clk` | in | 1 | Clock |
| `reset` | in | 1 | Asynchronous, **active-high** — also clears the accumulator |
| `en` | in | 1 | Asserted for one cycle when a MAC instruction is in EX |
| `A` | in | 16 | Operand A (signed) |
| `B` | in | 16 | Operand B (signed) |
| `accum_out` | out | 32 | Saturated accumulator value |
| `mac_overflow` | out | 1 | Sticky overflow flag |

Reset polarity is unified active-high across the MAC unit and every pipeline register, so no `~reset` inversions are needed anywhere in the design.

### Key sub-blocks

| Module | Description |
|--------|-------------|
| `booth_multiplier` | 16×16 signed multiplier — radix-4 Booth encoding feeding a Dadda CSA reduction tree |
| `csa_unit` | Carry-save adder used in the reduction tree |
| `accumulator_adder` | Saturating 32-bit signed accumulator with sticky overflow detection |

## Processor architecture

Classic 5-stage pipeline: **IF → ID → EX → MEM → WB**.

| Stage | Modules |
|-------|---------|
| IF | `program_counter`, `instruction_memory`, `if_id_register` |
| ID | `instruction_decoder`, `immediate_generator`, `control_unit`, `register_file`, `id_ex_register` |
| EX | `alu`, `rv32m_unit`, `mac_unit`, `forwarding_unit`, `ex_mem_register` |
| MEM | `data_memory`, `mem_wb_register` |
| WB | Write-back mux into `register_file` |

### Hazard handling

- **`forwarding_unit`** — EX/MEM and MEM/WB forwarding to both ALU operand inputs (`forwardA` / `forwardB`).
- **`hazard_detection_unit`** — detects the load-use hazard and inserts a stall bubble.
- Branch control signals are pipeline-registered into EX rather than resolved from raw ID outputs.

### Instruction support

- **RV32I base:** R-type ALU ops, I-type ALU ops, loads, stores, branches (`BEQ`, `BNE`, `BGE`, `BLT`), `JAL`, `JALR`, `LUI`, `AUIPC`.
- **RV32M** via `rv32m_unit`: `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU`.
- **Custom-0:** the MAC instruction described above.

### Memory

- `instruction_memory` — 256-word (1 KB) instruction ROM.
- `data_memory` — 256-word data RAM with `funct3`-aware byte/half/word access. Forced to distributed (LUT) RAM via a `ram_style` attribute so that asynchronous reads work correctly and synthesis stays fast; the cost is roughly 256 LUTs instead of one BRAM tile.

## Repository structure

| Category | Files |
|---|---|
| **Top levels** | `riscv_mac_processor.v`, `top_riscv_mac_single.v`, `riscv_mac_top.v` (ZedBoard wrapper), `mac_wrapper_single.v` |
| **MAC hardware** | `mac_unit.v`, `booth_multiplier.v`, `accumulator_adder.v`, `csa_unit.v`, `multiplier.v` |
| **Pipeline registers** | `if_id_register.v`, `id_ex_register.v`, `ex_mem_register.v`, `mem_wb_register.v` |
| **Control & hazards** | `control_unit.v`, `control_unit_mac_single.v`, `forwarding_unit.v`, `hazard_detection_unit.v` |
| **Datapath** | `program_counter.v`, `instruction_decoder.v`, `immediate_generator.v`, `register_file.v`, `alu.v`, `rv32m_unit.v`, `data_path_mac_single.v` |
| **Memory** | `instruction_memory.v`, `data_memory.v` |
| **Testbenches** | `riscv_mac_processor_tb.v`, `tb_single_mac_comprehensive.v`, `mac_unit_tb.v`, `booth_multiplier_tb.v`, `riscv_tb_2.v` |

### Choosing a top level

- `top_riscv_mac_single.v` — full debug top level. Exposes PC, instruction, decoded fields, all five immediates, ALU result, write-back data, branch flags, forwarding selects, load-use hazard, and the MAC accumulator/overflow. Use this for simulation.
- `riscv_mac_processor.v` — the processor core with a compact port list.
- `riscv_mac_top.v` — **ZedBoard** hardware wrapper: 50 MHz clock, active-high `CPU_RESET`, `pc_out[7:0]` on LD0–LD7, and a UART transmitter (`BAUD_DIV = 434` for 115200 baud) that emits a `RD=XX DATA=XXXXXXXX` line on every register write.

## Simulation

```bash
iverilog -o riscv_sim *.v -s tb_single_mac_comprehensive
vvp riscv_sim
gtkwave dump.vcd
```

In Vivado, add all sources, set the testbench as simulation top, and run Behavioral Simulation.

### Writing a MAC test program

Assemble the custom instruction by hand and load it into `instruction_memory`. For `MAC rd, rs1, rs2`:

```
instr = {7'b0000001, rs2, rs1, 3'b000, rd, 7'b0001011}
```

A dot product of two N-element vectors becomes N back-to-back MAC instructions; the accumulator carries the running sum, and the final `rd` write gives the result.

## FPGA implementation

Target board: **ZedBoard (Zynq-7000, XC7Z020)**.

| Signal | Pin | Function |
|---|---|---|
| `clk` | Y9 | 50 MHz oscillator |
| `reset` | T18 | CPU_RESET, active high |
| `leds[7:0]` | LD0–LD7 | Lower 8 bits of the PC |
| `uart_txd` | — | Connect to a USB-UART adapter, 115200 8N1 |

Add the board `.xdc` constraint file before generating a bitstream.

## Known issues / future work

- The MAC accumulator is cleared only on global reset; there is no `clr_acc` control or CSR-mapped read/write path. A dedicated accumulator-clear instruction (or a second custom-0 `funct3` encoding) would make consecutive independent dot products practical.
- Only the lower 16 bits of `rs1` and `rs2` are used. A 32×32 variant, or a SIMD encoding that packs two 16-bit lanes per register, is a natural extension.
- `mac_overflow` is sticky and reset-only clearable; exposing it as a readable status bit would be more useful to software.
- Several modules exist in both a general and a `_mac_single` variant (`control_unit` / `control_unit_mac_single`, and the several top levels). Consolidating these would make the build target unambiguous.
- No synthesis or timing report is checked in — adding Fmax, LUT/FF/DSP utilisation, and a cycle-count comparison of MAC versus `MUL`+`ADD` would quantify the benefit the design is arguing for.
- No formal or constrained-random verification; the testbenches are directed.

## Tools

- Verilog (IEEE 1364)
- Xilinx Vivado
- Icarus Verilog + GTKWave
- Target: ZedBoard, Zynq-7000 XC7Z020

## License

No license file is present. Add one if you intend others to reuse this work.
