# tProc v2 Architecture and ISA Manual

**Version:** 2.0  
**Platform:** QICK (Quantum Instrumentation Control Kit)  
**Instruction Width:** 72 Bits  

---

## 1. Introduction
The **tProc v2** is a high-performance, 5-stage pipelined processor designed for real-time control of quantum hardware. It succeeds the 64-bit tProc v1 by introducing a wider 72-bit instruction format, expanded register files, and native support for composite (fused) instructions.

---

## 2. Processor Architecture

### 2.1 Pipeline Stages
The processor utilizes a 5-stage pipeline:
1.  **FETCH (IF)**: Retrieves 72-bit instructions from PMEM.
2.  **DECODE (ID)**: Parses fields and reads the Register Bank.
3.  **EXECUTE 1 (X1)**: ALU operations and address calculations.
4.  **EXECUTE 2 (X2)**: Memory access and port updates.
5.  **WRITE BACK (WB)**: Updates registers with results.

### 2.2 Register Bank and Partitioning
The ISA supports **128 addressable registers** divided into 4 pages (32 registers each). The active register is selected by the 7-bit `RD`/`RS` field in the instruction.

| Page (Bit 6:5) | Type     | Full Name               | Purpose                     | Hardware Count                |
| :------------- | :------- | :---------------------- | :-------------------------- | :---------------------------- |
| `00`           | **SFR**  | **Special Function**    | Hardware-Software Interface | 16 implemented (`s0-s15`)     |
| `01`           | **DREG** | **Data Register**       | General Purpose Workspace   | 16 implemented (`r0-r15`)     |
| `10`           | **WREG** | **Waveform Register**   | Pulse Parameter Storage     | 16 mapped (`w0-w5` physical*) |
| `11`           | **RFU**  | **Reserved for Future** | Expansion Padding           | 0 implemented (Read as 0)     |

> [!NOTE]
> * **WREG Implementation**: Although 16 addresses are mapped, only **6 physical 32-bit registers** (`w0`-`w5`) are used. This provides 192 bits of storage, which is used to hold a single 168-bit Waveform Packet (Frequency, Phase, Envelope, Gain, etc.) sent to the Signal Generators.

#### 2.2.1 Special Function Registers (SFR: `s0` - `s15`)
| Addr                                               | Mnemonic                                               | Description                                                                                |
| :------------------------------------------------- | :----------------------------------------------------- | :----------------------------------------------------------------------------------------- |
| `s0`                                               | `zero`                                                 | Constant 0.                                                                                |
| `s1`                                               | `s_rand`                                               | 32-bit LFSR Random Number.                                                                 |
| [s2](../../../qick_lib/qick/asm_v2.py#L1721-L1735) | `s_cfg`                                                | Configuration [7:0] and Control [23:16].                                                   |
| `s3`                                               | `s_arith`                                              | ALU lower 32-bit result from DSP block.                                                    |
| `s4-s5`                                            | `s_div`                                                | Divider Quotient (`s4`) and Remainder (`s5`).                                              |
| `s6-s7`                                            | `s_ext`                                                | External Input Data (Muxed via [s2](../../../qick_lib/qick/asm_v2.py#L1721-L1735) config). |
| `s8-s9`                                            | `s_port`                                               | Last read Input Port Data: `s8` (Low 32b), `s9` (High 32b).                                |
| `s10`                                              | `s_status`                                             | Status flags (Arithmetic Rdy, New Port Data, FIFO full).                                   |
| `s11`                                              | `s_time`                                               | **User Time**: Lower 32 bits of relative clock.                                            |
| `s12-s13`                                          | `s_core`                                               | Core-to-Core / PS-to-Core mailbox registers.                                               |
| `s14`                                              | `s_out_time`                                           | **Execution Time**: 32-bit timestamp for next output.                                      |
| `s15`                                              | [s_addr](../../../qick_lib/qick/asm_v2.py#L2621-L2637) | Return address for CALL/RET or PC logic.                                                   |

---

## 3. Time Management Architecture

### 3.1 The 48-bit Master Clock
The tProc v2 hardware maintains a **48-bit absolute timer** (`time_abs`) within the FPGA logic.

### 3.2 Relative Timing (tProc v2 Core)
To simplify programming and instruction width, the **tProc v2 core** (the soft-core on the FPGA) operates in a **32-bit relative window**.
- **Reference Time (`T_ref`)**: A 48-bit internal hardware register.
- **User Time (`s11`)**: The tProc v2 core sees this as [(Absolute_Time - T_ref)[31:0]](../../../qick_lib/qick/asm_v1.py#L1333-L1343).
- **Scheduled Time (`s14`)**: When an instruction is sent to a port, the core uses the 32-bit `s14` value, which the hardware **sign-extends to 48 bits** and adds to `T_ref`.

### 3.3 Interaction with the PS (ARM)
The **PS (Processing System / ARM)** typically handles the high-level initialization. When a Python script starts a QICK program:
1. The PS set the initial `T_ref` or resets the `time_abs` via AXI registers.
2. The **tProc v2 core** then takes over, executing the real-time pulse sequence within its 32-bit relative window.

### 3.4 Conceptual Walkthrough: Scheduling a Pulse
When `abs_time >= Output_Time`, the pulse is emitted.

Imagine the master clock (`time_abs`) has been running for a long time.

1.  **Anchor the Reference**: The PS (Python) sets `T_ref = 1,000,000` to start a new experiment session.
2.  **Read User Time**: The tProc v2 code reads `s11`. If current `time_abs = 1,001,000`, then `s11` returns **1,000** (a local offset from the anchor).
3.  **Schedule a Pulse**: You want to fire a pulse 500 cycles from "now". You calculate `s14 = s11 + 500 = 1,500`.
4.  **Hardware Dispatch**:
    - The hardware calculates `Output_Time = T_ref + sign_ext(1,500) = 1,000,000 + 1,500 = 1,001,500`.
    - The pulse waits until `time_abs >= 1,001,500`.
5.  **Execution**: 500 cycles later, the pulse is emitted with nanosecond precision.

### 3.5 Why Sign-Extend s14?
The 32-bit `s14` value is **sign-extended** to 48 bits. This has a critical implication:
- **Positive Offsets (0 to 2^31 - 1)**(less than 0x7fffffff): `s14` values move the pulse into the **future** relative to `T_ref`. 
- **Negative Offsets (2^31 to 2^32 - 1)**: These values are treated as negative (Bit 31 = 1) and would schedule a pulse in the **past** relative to `T_ref`.

> [!WARNING]
> To avoid accidental "past" scheduling, always ensure your relative offset from `T_ref` stays within the **31-bit integer range** (approx. 2.1 seconds at 1GHz). If you need longer delays, use `INC T_ref` to shift your anchor forward.

This architecture replaces the v1 `t_off` register with a more flexible hardware-managed reference offset.

---

## 4. Instruction Bit-Mapping (72-Bit)

The 72-bit instruction is split into a **Header [71:56]** (also called `op_code` in RTL) and a **Payload [55:0]** (`op_data`).

### 4.1 Header Bit-Fields [71:56]
These bits are consistent across most instructions:

| Bit(s) | Field                                                           | Description                                                                                                 |
| :----- | :-------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------- |
| 71:69  | `OpCode`                                                        | **Category**: CFG, BR, INT, EXT, REG_WR, MEM_WR, PORT_WR.                                                   |
| 68     | [AI](../../../qick_lib/qick/tprocv2_assembler.py#L1874-L1912)   | **Address Immediate**: 1 = Use Payload [55:45] as address; 0 = Use Register.                                |
| 67:66  | `DF`                                                            | **Data Format**: 00=Addr, 01=16 signed immediate+rsD0+rsD1, 10=24b signed immediate+rsD0, 11=32b immediate. |
| 65:63  | [COND](../../../qick_lib/qick/tprocv2_assembler.py#L1147-L1157) | **Condition**: Z, S, NZ, NS, Flag, etc.                                                                     |
| 62     | [SO](../../../qick_lib/qick/tprocv2_assembler.py#L1202-L1307)   | **Sub-Option**: Used to differentiate mnemonics within a category.                                          |
| 61     | `TO`                                                            | **Time Option**: 1 = Instruction is timed (uses `s14`); 0 = Immediate.                                      |
| 60     | `UF`                                                            | **Update Flag**: 1 = Update Z/S status flags based on result.                                               |
| 59:56  | `SUB_OP`                                                        | **Sub-Operation**: ALU op code or secondary write enables.                                                  |

### 4.2 Payload Bit-Fields [55:0]
The payload (`op_data`) contains the operands, addresses, and destination register. Its interpretation is influenced by the Header bits (especially [AI](../../../qick_lib/qick/tprocv2_assembler.py#L1874-L1912) and `DF`).

| Bit(s) | Default Field       | Description                                                                                                    |
| :----- | :------------------ | :------------------------------------------------------------------------------------------------------------- |
| 55:45  | `IMM_ADDR` / `rsA0` | 11-bit Immediate Address or Source Register A0.                                                                |
| 44:39  | `rsA1`              | 6-bit Source Register A1 (Used in offset calculations). Only use SFR and DREG pages, so 6 bits will be enough. |
| 38:7   | `IMM_DATA` / `rsD`  | Up to 32-bit Immediate Data or Source Registers D0/D1.                                                         |
| 6:0    | `RD`                | **Destination Register**: 7-bit address (Page + Index).                                                        |

> [!TIP]
> **Data Multiplexing**: If `DF == 11` (32-bit mode), the entire [38:7] range is used for a single immediate value. In other modes, this space is subdivided to fit two register addresses (`rsD0`, `rsD1`) and smaller immediate constants.

---

## 5. Category-Specific Encoding Rules

Within each 3-bit `OpCode`, the hardware uses [SO](../../../qick_lib/qick/tprocv2_assembler.py#L1202-L1307), `TO`, and `SUB_OP` bits to decide the final execution logic.

### 5.1 [001] BRANCH Category
- **`JUMP`**: `SO = 0`. Jumps to target.
- **`CALL`**: `SO = 1, TO = 0`. Jumps and saves return address to `s15`.
- **`RET`**: `SO = 1, TO = 1`. Jumps back to address in `s15`.

### 5.2 [100] REG_WR Category (General ALU)
- **Primary ALU (`wra`)**: `SO = 0, TO = 0`.
    - `SUB_OP [59:56]` determines which of the **16 ALU ops** (+, -, AND, etc.) is used.
- **Fused Operation**: If `SUB_OP [59]` is 1, it allows writing to a second register or combining with other tasks.

### 5.3 [101] MEM_WR Category
- **[DMEM_WR](../../../qick_lib/qick/tprocv2_assembler.py#L1440-L1465)**: `SO = 0`. Writes 32-bit `rsD0` to Data Memory.
- **[WMEM_WR](../../../qick_lib/qick/tprocv2_assembler.py#L1466-L1493)**: `SO = 1`. Writes the 168-bit `WREG` packet to Waveform Memory.

### 5.4 [110] PORT_WR Category
- **`DPORT_WR` / `RD`**: `SO = 0`. Interacts with 32-bit peripheral ports.
    - `Header [57]` (bit 7 of Header): 1 = Write, 0 = Read.
- **`WPORT_WR`**: `SO = 1`. Sends pulse parameters to Signal Generators.
- **`TRIG`**: Specialized `WPORT_WR` for fast bit-toggling.

### 5.5 [010] INT_CTRL Category
- **`ALU_OP`**: The sub-opcode is encoded in the lower bits of the Header [59:56].
- **Muxing**: Defines whether we are interacting with `FLAG`, `TIME`, [ARITH](../../../qick_lib/qick/tprocv2_assembler.py#L1799-L1873), or `DIV`.

---

## 6. Instruction Hierarchy Table

The 3-bit `OpCode` [71:69] defines the **execution category**. Within each category, sub-fields (like `ALU_OP`, [COND](../../../qick_lib/qick/tprocv2_assembler.py#L1147-L1157), or `Source/Dest` selection) define the specific assembly mnemonic.

| OpCode (3b) | Category     | Assembly Mnemonics                                                                                                                     | Description                                                 |
| :---------- | :----------- | :------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------- |
| `000`       | **CFG**      | `NOP`, `TEST`                                                                                                                          | System config, no-op, or flag-only updates.                 |
| `001`       | **BRANCH**   | `JUMP`, `CALL`, `RET`                                                                                                                  | Control flow changes (Conditional or Unconditional).        |
| `010`       | **INT_CTRL** | `FLAG`, `TIME`, [ARITH](../../../qick_lib/qick/tprocv2_assembler.py#L1799-L1873), `DIV`                                                | Internal logic (Flags, Time base, DSP, Divider).            |
| `011`       | **EXT_CTRL** | `NET`, `COM`, `PA`, `PB`                                                                                                               | External connectivity (Network, Custom Peripherals).        |
| `100`       | **REG_WR**   | [REG_WR](../../../qick_lib/qick/tprocv2_assembler.py#L1351-L1439)                                                                      | Primary ALU unit (16 operations: ADD, SUB, AND, XOR, etc.). |
| `101`       | **MEM_WR**   | [DMEM_WR](../../../qick_lib/qick/tprocv2_assembler.py#L1440-L1465), [WMEM_WR](../../../qick_lib/qick/tprocv2_assembler.py#L1466-L1493) | Memory storage (Data Memory or Waveform Memory).            |
| `110`       | **PORT_WR**  | `TRIG`, `DPORT_WR`, `WPORT_WR`                                                                                                         | External Port I/O (Triggers, Data, or Pulses).              |

### 5.1 Category Deep Dive

#### [000] CFG / System
- **`NOP`**: Does nothing.
- **`TEST`**: Performs an ALU operation and updates flags (`Z`, `S`) based on the result, but **discards** the data (no register write).

#### [001] BRANCH / Flow Control
- **`JUMP`**: Standard branch. Target can be immediate (`AI=1`) or register-based (`AI=0`).
- **`CALL`**: Subroutine call. Automatically saves `PC+1` into `s15` ([s_addr](../../../qick_lib/qick/asm_v2.py#L2621-L2637)).
- **`RET`**: Returns from a call by jumping to the address stored in `s15`.

#### [010] INT_CTRL / Core Logic
- **`FLAG`**: Set, Reset, or Toggle internal flags (via `ALU_OP` field).
- **`TIME`**: Master clock management.
    - `SET T_ref`: Set base reference time.
    - `INC T_ref`: Increment reference to shift the 32-bit window.
- **[ARITH](../../../qick_lib/qick/tprocv2_assembler.py#L1799-L1873)**: Accesses the DSP MAC unit for high-speed [(A*B)+C](../../../qick_lib/qick/asm_v2.py#L566-L575) operations.
- **`DIV`**: Accesses the Integer Divider (results placed in `s4`, `s5`).

#### [100] REG_WR / General ALU
This is the most common instruction. It supports **16 distinct operations**:
- **Arithmetic**: `+`, `-`, `ABS`, `SWP` (Swap bytes).
- **Logical**: `AND`, [OR](../../../qick_lib/qick/tprocv2_assembler.py#L1545-L1654), `XOR`, `NOT`.
- **Shifts**: `ASR` (Arithmetic Shift Right), `LSH` (Logical Shift), `SL` (Shift Left), [SR](../../../qick_lib/qick/tprocv2_assembler.py#L421-L445) (Shift Right).
- **Other**: `MSK` (Mask), `CAT` (Concatenate), `PAR` (Parity).

#### [110] PORT_WR / I/O Dispatch
- **`TRIG`**: Optimized for 1-bit trigger pins (Fast Pulse).
- **`WPORT_WR`**: The core "Pulse" instruction. Dispatches a 168-bit `WREG` packet to a Signal Generator port at a scheduled `s14` time.
- **`DPORT_WR` / `RD`**: Generic 32-bit data interface for peripherals.

---

## 6. Assembler Mnemonics
The [tprocv2_assembler.py](../../../tprocv2_assembler.py) translates high-level syntax:
```python
# Example: Trigger port 5 and increment counter r10
TRIG p5 set -wr(r10 op) -op(r10 + #1)
```
Into the binary:
`110 (Op) | 1 (AI) | 11 (DF) | 000 (Cond) | ... | 00000101 (Port) | ... | 0001010 (RD=r10)`

---

## 7. Programming Best Practices
1.  **Hazard Management**: Avoid reading a register immediately after writing to it in back-to-back instructions unless forwarding is confirmed for that specific path.
2.  **Timing Determinism**: Always load `s14` before a sequence of pulse instructions to maintain phase-coherence.
3.  **Fused Logic**: Use the `-wr` option in [PORT_WR](../../../qick_lib/qick/tprocv2_assembler.py#L1545-L1654) to handle loop increments without needing extra [REG_WR](../../../qick_lib/qick/tprocv2_assembler.py#L1351-L1439) cycles.
